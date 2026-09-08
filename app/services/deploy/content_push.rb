# frozen_string_literal: true

require "json"

module Deploy
  class ContentPush
    SNAPSHOT = "tmp/content/snapshot.json"
    STATS_SQL = <<~SQL
      SELECT relname, n_tup_ins, n_tup_upd, n_tup_del FROM pg_stat_user_tables
      WHERE schemaname = current_schema()
    SQL
      .squish
    SETTINGS_SQL = "SELECT data FROM settings ORDER BY id LIMIT 1"
    FINGERPRINT_KEYS = %w[sync_fingerprints profile_vocabulary].freeze

    Refused = Class.new(StandardError)
    Report = Data.define(:plans, :cascade) do
      def empty? = plans.all?(&:empty?)

      def deleted_lexemes = plans.find { |plan| plan.table.name == "lexemes" }&.deletes || []
    end

    def self.from_env(io: $stdout)
      new(
        mirror_url: ENV.fetch("MIRROR_DATABASE_URL") { abort("MIRROR_DATABASE_URL is not set; see .env.dev") },
        prod_url: ENV.fetch("PROD_DATABASE_URL") { abort("PROD_DATABASE_URL is not set; see .env.dev") },
        io:
      )
    end

    def self.cascade? = ActiveModel::Type::Boolean.new.cast(ENV["CASCADE"]).present?

    def initialize(mirror_url:, prod_url:, io: $stdout, snapshot: Rails.root.join(SNAPSHOT))
      @mirror_url = mirror_url
      @prod_url = prod_url
      @io = io
      @snapshot = Pathname(snapshot)
    end

    def refresh
      mirror = connect(@mirror_url)
      prod = connect(@prod_url)
      diff = ContentDiff.new(source: prod, target: mirror)

      plans = ContentTables::ORDERED.map { |table| diff.plan(table) }
      mirror.transaction do
        transfer(diff, plans, "refresh")
        copy_settings(prod, mirror)
      end

      remember(diff, mirror)
      @io.puts("refresh: the mirror now carries the production content")
    ensure
      mirror&.close
      prod&.close
    end

    def plan(cascade: false)
      mirror = connect(@mirror_url)
      prod = connect(@prod_url)
      diff = ContentDiff.new(source: mirror, target: prod)
      snapshot = read_snapshot

      check_written_tables(mirror, snapshot)
      check_untouched_production(diff, prod, snapshot)
      plans = ContentTables::ORDERED.map { |table| diff.plan(table) }
      report = Report.new(plans:, cascade: user_references(prod, plans))
      check_cascade(report, cascade)
      report
    ensure
      mirror&.close
      prod&.close
    end

    def push(cascade: false)
      report = plan(cascade:)
      return report if report.empty?

      mirror = connect(@mirror_url)
      prod = connect(@prod_url)
      diff = ContentDiff.new(source: mirror, target: prod)

      prod.transaction do
        cascade_user_rows(prod, report) if cascade
        transfer(diff, report.plans, "push")
        merge_settings(mirror, prod)
      end

      remember(diff, mirror)
      @io.puts("push: production now carries the mirror content")
      report
    ensure
      mirror&.close
      prod&.close
    end

    def print(report)
      report.plans.each { |plan| @io.puts(plan.summary) unless plan.empty? }
      @io.puts("plan: nothing to push") if report.empty?
      report.cascade.each { |table, count| @io.puts("cascade #{table}: #{count} rows follow deleted lexemes") }
    end

    private

    def connect(url) = ContentDiff.connect(url)

    def transfer(diff, plans, label)
      plans.reverse_each { |plan| diff.delete(plan.table, plan.deletes) }
      plans.each do |plan|
        next if plan.empty?

        counts = diff.apply(plan.with(deletes: []))
        @io.puts(
          format(
            "%s %-24s +%-7d ~%-7d -%d",
            label,
            plan.table.name,
            counts[:inserted],
            counts[:updated],
            plan.deletes.length
          )
        )
      end

      diff.copy_sequences
      ContentTables::ORDERED.each { |table| diff.verify!(table) }
    end

    def copy_settings(from, to)
      data = from.exec(SETTINGS_SQL).getvalue(0, 0)
      return if data.nil?

      touched = to
        .exec_params(
          "UPDATE settings SET data = $1, updated_at = now() WHERE id = (SELECT id FROM settings ORDER BY id LIMIT 1)",
          [data]
        )
        .cmd_tuples
      if touched.zero?
        to.exec_params("INSERT INTO settings (data, created_at, updated_at) VALUES ($1, now(), now())", [data])
      end
    end

    def merge_settings(from, to)
      data = JSON.parse(from.exec(SETTINGS_SQL).getvalue(0, 0) || "{}").slice(*FINGERPRINT_KEYS)
      to.exec_params(
        "UPDATE settings SET data = data || $1::jsonb, updated_at = now() WHERE id = (SELECT id FROM settings ORDER BY id LIMIT 1)",
        [JSON.generate(data)]
      )
    end

    def stats(connection)
      connection.exec("SELECT pg_stat_clear_snapshot()")
      connection.exec(STATS_SQL).each_with_object({}) do |row, memo|
        memo[row["relname"]] = [row["n_tup_ins"], row["n_tup_upd"], row["n_tup_del"]].map(&:to_i)
      end
    end

    def remember(diff, mirror)
      digests = ContentTables::ORDERED.to_h { |table| [table.name, diff.digest(mirror, table)] }
      @snapshot.dirname.mkpath
      @snapshot.write(
        JSON.pretty_generate("taken_at" => Time.now.utc.iso8601, "digests" => digests, "stats" => stats(mirror))
      )
    end

    def read_snapshot
      raise Refused, "no snapshot at #{@snapshot}; run content:refresh first" unless @snapshot.exist?

      JSON.parse(@snapshot.read)
    end

    def check_written_tables(mirror, snapshot)
      before = snapshot.fetch("stats")
      strays = stats(mirror).select do |name, counts|
        counts != before.fetch(name, counts) &&
          !ContentTables.names.include?(name) &&
          !ContentTables::BOOKKEEPING.include?(name)
      end

      return if strays.empty?

      raise Refused, "the sync wrote to #{strays.keys.join(", ")}, which content push does not carry"
    end

    def check_untouched_production(diff, prod, snapshot)
      expected = snapshot.fetch("digests")
      drifted = ContentTables::ORDERED.map(&:name).select { |name|
        diff.digest(prod, ContentTables.find(name)) != expected[name]
      }
      return if drifted.empty?

      raise Refused, "production changed since the snapshot in #{drifted.join(", ")}; run content:refresh again"
    end

    def user_references(prod, plans)
      ids = plans.find { |plan| plan.table.name == "lexemes" }&.deletes&.flatten || []
      return {} if ids.empty?

      ContentTables::USER_REFERENCES
        .filter_map do |table, column|
          count = prod
            .exec_params("SELECT count(*) FROM #{table} WHERE #{column} = ANY($1::bigint[])", ["{#{ids.join(",")}}"])
            .getvalue(0, 0)
            .to_i
          [table, count] if count.positive?
        end
        .to_h
    end

    def check_cascade(report, cascade)
      return if report.cascade.empty? || cascade

      raise(
        Refused,
        "deleted lexemes are still referenced by #{report.cascade.keys.join(", ")}; rerun with CASCADE=yes to remove those rows too"
      )
    end

    def cascade_user_rows(prod, report)
      ids = "{#{report.deleted_lexemes.flatten.join(",")}}"
      ContentTables::USER_REFERENCES.each do |table, column|
        prod.exec_params("DELETE FROM #{table} WHERE #{column} = ANY($1::bigint[])", [ids])
      end
    end
  end
end
