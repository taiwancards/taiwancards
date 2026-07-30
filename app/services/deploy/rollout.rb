# frozen_string_literal: true

require "open3"
require "shellwords"

module Deploy
  class Rollout
    Step = Struct.new(:name, :status, :note, keyword_init: true)

    PROJECT_DIR = "/opt/render/project/src"

    REMOTE_TASKS = [
      {task: "db:prepare", what: "migrations"},
      {task: "db:seed", what: "settings and admin"},
      {task: "textbook:load", what: "Textbook lessons from the exports on disk"},
      {task: "deploy:sync", what: "importers for the files that changed"},
      {task: "fonts:install", what: "web fonts into FONT_DIR"}
    ].freeze

    FILLERS = %w[
      Huayu::GlossOverrideEnricher
      Huayu::SenseMeaningFiller
      Huayu::CollocationMeaningFiller
      Huayu::ChengyuImporter
      Huayu::PosImporter
      Huayu::LiangciImporter
      Huayu::ThesaurusImporter
      Lexemes::RegisterMix
    ]
      .freeze

    def initialize(
      server:,
      region: nil,
      database: nil,
      only: nil,
      skip: nil,
      dry_run: false,
      checksum: false,
      io: $stdout
    )
      @server = server
      @region = region.presence
      @database = database.presence
      @sections = Catalog.select(only:, skip:)
      @dry_run = dry_run
      @checksum = checksum
      @io = io
      @steps = []
    end

    attr_reader :sections, :steps

    def shipper
      @shipper ||= ::Content::Shipper.new(server: @server, region: @region, io: @io)
    end

    def host = shipper.host

    def plan
      lines = @sections.map do |section|
        state = if section.exist?
          human(section.bytes)
        else
          section.required ? "MISSING" : "absent (optional)"
        end

        format("  %-16s %-14s %s", section.id, state, section.what)
      end

      lines << ""
      lines << format("  total to transfer: %s", human(@sections.select(&:exist?).sum(&:bytes)))
      lines <<
        "  on the server: #{REMOTE_TASKS.map { |entry| entry[:task] }.join(", ")}, gloss fillers"
      lines <<
        (@database ? "  dictionary: direct write to the production database" : "  dictionary: SKIPPED — PROD_DATABASE_URL is not set")
      lines
    end

    def call
      check_local!
      say("\nDRY RUN: nothing is transferred and nothing is written.") if @dry_run

      say("\n━━ 1/4 · files onto the Render disk ━━")
      shipper.ensure_dirs(@sections.map(&:to)) unless @dry_run
      @sections.each { |section| ship(section) }

      say("\n━━ 2/4 · dictionary into the production database ━━")
      @dry_run ? skip_in_dry_run("dictionary") : push_dictionary

      say("\n━━ 3/4 · database on the server ━━")
      @dry_run ? skip_in_dry_run("server") : run_remote_tasks

      say("\n━━ 4/4 · verification ━━")
      verify

      report
      @steps
    end

    private

    def check_local!
      missing = @sections.select { |section| section.required && !section.exist? }
      return if missing.empty?

      raise(
        <<~MESSAGE
          Nothing to roll out — these required sections are missing locally:
          #{missing.map { |section| "  #{section.from} — #{section.what}" }.join("\n")}

          data/ lives in its own repository and is not checked out here. Clone it
          next to the application, or exclude the section explicitly:
            SKIP=#{missing.map(&:id).join(",")} CONFIRM=yes rake deploy:content
        MESSAGE
      )
    end

    def ship(section)
      unless section.exist?
        return record(section.id, :skipped, "absent locally; server not modified")
      end

      if section.mode == :atomic
        atomic(section)
      else
        shipper.sync_paths(section.sync_sources, section.to, dry_run: @dry_run, checksum: @checksum)
        record(section.id, @dry_run ? :dry : :done, "#{section.count} files, #{human(section.bytes)}")
      end

    rescue => e
      record(section.id, :failed, e.message)
      raise if section.required
    end

    def atomic(section)
      result = ::Pronunciation::Sync
        .new(
          server: @server,
          region: @region || ::Pronunciation::Sync::DEFAULT_REGION,
          io: @io
        )
        .call(dry_run: @dry_run)

      record(
        section.id,
        @dry_run ? :dry : :done,
        "added #{result.added.size}, changed #{result.changed.size}, unchanged #{result.unchanged}"
      )
    end

    def skip_in_dry_run(name)
      say("  skipped: dry run")
      record(name, :dry, "dry run")
    end

    def push_dictionary
      unless @database
        say(
          "  skipped: PROD_DATABASE_URL is not set; step 3 fillers cover the dictionary"
        )
        return record("dictionary", :skipped, "no PROD_DATABASE_URL")
      end

      dump = Rails.root.join("tmp/push-dictionary.tsv")
      dump.dirname.mkpath

      rows = DictionaryDump.new(DictionaryDump::KINDS).write(dump)
      return record("dictionary", :skipped, "nothing to push") if rows.zero?

      say(format("  dumped %d rows (%s)", rows, human(dump.size)))
      DictionaryPush.new(@database, dump, DictionaryDump::KINDS, io: @io).call
      record("dictionary", :done, "#{rows} lexemes")
    rescue => e
      record("dictionary", :failed, e.message)
      raise
    ensure
      dump&.delete if dump&.exist?
    end

    def run_remote_tasks
      shipper.run_remote(remote_script)
      record("server", :done, REMOTE_TASKS.map { |entry| entry[:task] }.join(", "))
    rescue => e
      say("  ⚠ SSH failed (#{e.message}); the database is updated on the next Render restart")
      record("server", :failed, e.message)
    end

    def remote_script
      runs = REMOTE_TASKS.map { |entry| "run #{entry[:task]}" }

      <<~SH
        cd "${RENDER_PROJECT_DIR:-#{PROJECT_DIR}}"
        rm -f /var/data/render-content.tar.gz
        fail=0
        run() { echo "-- $1"; bundle exec rails "$1" || { echo "!! failed: $1"; fail=1; }; }
        #{runs.join("\n")}
        echo "-- gloss fillers"
        bundle exec rails runner #{filler_script.shellescape} || fail=1
        exit $fail
      SH
        .strip
        .gsub("\n", "; ")
    end

    def filler_script
      "%w[#{FILLERS.join(" ")}].each { |n| c = n.safe_constantize; " \
        "puts(\"\#{n}: \#{c ? c.new.call.inspect : \"not in this build\"}\") }"
    end

    def verify
      unless @database
        say("  skipped: no PROD_DATABASE_URL to compare against")
        return record("verification", :skipped, "no PROD_DATABASE_URL")
      end

      remote = remote_counts
      behind = []

      ContentTables::ALL.each do |table|
        local = local_count(table)
        there = remote[table]

        mark = if there.nil?
          "no such table on the server"
        elsif there >= local
          "ok"
        else
          behind << table
          "behind by #{local - there}"
        end

        say(format("  %-24s local %9d   server %9s   %s", table, local, there || "—", mark))
      end

      say("\n  #{hint_for(behind)}") if behind.any?
      record(
        "verification",
        behind.empty? ? :done : :warned,
        behind.empty? ? "all counts match" : "behind: #{behind.join(", ")}"
      )
    rescue => e
      say("  ⚠ verification failed: #{e.message}")
      record("verification", :failed, e.message)
    end

    def hint_for(behind)
      routes = behind.group_by { |table| ContentTables::INCREMENTAL[table] || "full dump" }
      lines = routes.map { |route, tables| "#{tables.join(", ")} → #{route}" }
      if routes.key?("full dump")
        lines <<
          "full dump: rake content:dump, then content:ship and content:restore on the server"
      end

      lines.join("\n  ")
    end

    def local_count(table)
      ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table}").to_i
    rescue ActiveRecord::StatementInvalid
      0
    end

    def remote_counts
      present = psql("SELECT tablename FROM pg_tables WHERE schemaname = 'public'")
        .lines
        .map(&:strip)
        .compact_blank
      wanted = ContentTables::ALL & present
      return {} if wanted.empty?

      query = wanted.map { |table| "SELECT '#{table}' AS t, count(*) AS n FROM #{table}" }.join(" UNION ALL ")
      psql(query)
        .lines
        .filter_map do |line|
          table, count = line.strip.split("|")
          [table, count.to_i] if table.present?
        end
        .to_h
    end

    def psql(query)
      out, err, status = Open3.capture3("psql", @database, "-tA", "-F", "|", "-c", query)
      raise "psql: #{err.strip.presence || "exit #{status.exitstatus}"}" unless status.success?

      out
    end

    ICONS = {done: "✓", skipped: "·", dry: "?", warned: "!", failed: "✗"}.freeze

    def report
      say("\n#{"─" * 64}")
      @steps.each { |step| say(format("  %s %-16s %s", ICONS.fetch(step.status, "?"), step.name, step.note)) }
    end

    def record(name, status, note)
      @steps << Step.new(name:, status:, note:)
    end

    def say(line) = @io.puts(line)

    def human(bytes)
      units = %w[B KB MB GB]
      value = bytes.to_f
      unit = 0
      while value >= 1024 && unit < units.length - 1
        value /= 1024
        unit += 1
      end

      format("%.1f %s", value, units[unit])
    end
  end
end
