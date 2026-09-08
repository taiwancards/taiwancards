# frozen_string_literal: true

require "pg"
require "digest"

module Deploy
  class ContentDiff
    BUCKET = 8192

    SESSION = [
      "SET extra_float_digits = 3",
      "SET datestyle = 'ISO, YMD'",
      "SET timezone = 'UTC'",
      "SET intervalstyle = 'postgres'",
      "SET bytea_output = 'hex'",
      "SET client_min_messages = warning",
      "SET statement_timeout = 0",
      "SET lock_timeout = '10s'"
    ].freeze

    COLUMNS_SQL = <<~SQL
      SELECT column_name FROM information_schema.columns
      WHERE table_schema = current_schema() AND table_name = $1 AND is_generated = 'NEVER'
      ORDER BY ordinal_position
    SQL
      .squish

    Plan = Data.define(:table, :inserts, :updates, :deletes) do
      def empty? = inserts.empty? && updates.empty? && deletes.empty?

      def summary = format("%-24s +%-7d ~%-7d -%d", table.name, inserts.length, updates.length, deletes.length)
    end

    Mismatch = Class.new(StandardError)

    def self.connect(url)
      connection = PG.connect(url)
      SESSION.each { |statement| connection.exec(statement) }
      connection
    end

    def initialize(source:, target:)
      @source = source
      @target = target
      @columns = {}
    end

    def columns(table)
      @columns[table.name] ||= begin
        ours = @source.exec_params(COLUMNS_SQL, [table.name]).column_values(0)
        theirs = @target.exec_params(COLUMNS_SQL, [table.name]).column_values(0)
        raise Mismatch, "#{table.name}: columns differ between the two databases" if ours != theirs
        raise Mismatch, "#{table.name}: no such table" if ours.empty?

        table.surrogate? ? ours - ["id"] : ours
      end
    end

    TIMESTAMPS = %w[created_at updated_at].freeze

    def compared(table) = columns(table) - TIMESTAMPS

    def buckets(connection, table)
      sql = <<~SQL
        SELECT #{table.bucket} / #{BUCKET} AS bucket, count(*) AS n,
               md5(string_agg(#{row_digest(table)}, '' ORDER BY #{list(table.key)})) AS digest
        FROM #{table.name} WHERE #{table.predicate} GROUP BY 1
      SQL
        .squish
      connection.exec(sql).each_with_object({}) { |row, memo|
        memo[row["bucket"].to_i] = [row["n"].to_i, row["digest"]]
      }
    end

    def digest(connection, table)
      Digest::MD5.hexdigest(buckets(connection, table).sort.flatten.join(","))
    end

    def plan(table)
      ours = buckets(@source, table)
      theirs = buckets(@target, table)
      changed = (ours.keys | theirs.keys).select { |bucket| ours[bucket] != theirs[bucket] }
      return Plan.new(table:, inserts: [], updates: [], deletes: []) if changed.empty?

      mine = hashes(@source, table, changed)
      stored = hashes(@target, table, changed)
      shared = mine.keys & stored.keys

      Plan.new(
        table:,
        inserts: mine.keys - stored.keys,
        updates: shared.reject { |key| mine[key] == stored[key] },
        deletes: stored.keys - mine.keys
      )
    end

    def apply(plan)
      table = plan.table
      deleted = delete(table, plan.deletes)
      inserted, updated = upsert(table, plan.inserts + plan.updates)
      {inserted:, updated:, deleted:}
    end

    def delete(table, keys)
      return 0 if keys.empty?

      stage_keys(@target, table, keys)
      deleted = @target
        .exec("DELETE FROM #{table.name} t USING content_keys k WHERE #{join(table, "t", "k")}")
        .cmd_tuples
      @target.exec("DROP TABLE content_keys")
      deleted
    end

    def verify!(table)
      return if buckets(@source, table) == buckets(@target, table)

      raise Mismatch, "#{table.name}: the two databases still differ after the push"
    end

    def copy_sequences(tables = ContentTables::ORDERED)
      tables.select(&:sequenced?).each do |table|
        from = sequence(@source, table)
        to = sequence(@target, table)
        next if from.nil? || to.nil?

        state = @source.exec("SELECT last_value, is_called FROM #{from}").first
        @target.exec_params("SELECT setval($1, $2, $3)", [to, state["last_value"], state["is_called"] == "t"])
      end
    end

    private

    def upsert(table, keys)
      return [0, 0] if keys.empty?

      names = list(columns(table))
      @target.exec("CREATE TEMP TABLE content_patch AS SELECT #{names} FROM #{table.name} WITH NO DATA")
      stream(table, keys)
      updated = update(table)
      inserted = @target
        .exec(
          <<~SQL
            INSERT INTO #{table.name} (#{names}) SELECT #{names} FROM content_patch p
            WHERE NOT EXISTS (SELECT 1 FROM #{table.name} t WHERE #{join(table, "t", "p")})
          SQL
            .squish
        )
        .cmd_tuples
      @target.exec("DROP TABLE content_patch")
      [inserted, updated]
    end

    def stream(table, keys)
      stage_keys(@source, table, keys)
      names = list(columns(table))
      query = "SELECT #{qualified(columns(table), "t")} FROM #{table.name} t JOIN content_keys k ON #{join(table, "t", "k")}"

      @target.copy_data("COPY content_patch (#{names}) FROM STDIN") do
        @source.copy_data("COPY (#{query}) TO STDOUT") do
          while (chunk = @source.get_copy_data)
            @target.put_copy_data(chunk)
          end
        end
      end

      @source.exec("DROP TABLE content_keys")
    end

    def update(table)
      assignments = (columns(table) - table.key).map { |name| "#{name} = p.#{name}" }.join(", ")
      return 0 if assignments.empty?

      changed = "ROW(#{qualified(compared(table), "t")}) IS DISTINCT FROM ROW(#{qualified(compared(table), "p")})"
      sql = "UPDATE #{table.name} t SET #{assignments} FROM content_patch p WHERE #{join(table, "t", "p")} AND #{changed}"
      parked = []

      begin
        @target.exec("SAVEPOINT content_update")
        count = @target.exec(sql).cmd_tuples
        @target.exec("RELEASE SAVEPOINT content_update")
        count
      rescue PG::UniqueViolation => e
        @target.exec("ROLLBACK TO SAVEPOINT content_update")
        index = e.result.error_field(PG::PG_DIAG_CONSTRAINT_NAME)
        raise Mismatch, "#{table.name}: #{e.message.lines.first.strip}" if index.nil? || parked.include?(index)

        park(table, index)
        parked << index
        retry
      end
    end

    PARKING = {
      "integer" => -> (column) { "-(#{column}) - 1" },
      "bigint" => -> (column) { "-(#{column}) - 1" },
      "smallint" => -> (column) { "-(#{column}) - 1" },
      "text" => -> (column) { "chr(1) || #{column}" },
      "character varying" => -> (column) { "chr(1) || #{column}" }
    }.freeze

    INDEX_COLUMNS_SQL = <<~SQL
      SELECT a.attname, format_type(a.atttypid, a.atttypmod)
      FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
      WHERE c.relname = $1
      ORDER BY array_position(i.indkey, a.attnum)
    SQL
      .squish

    FOREIGN_COLUMNS_SQL = <<~SQL
      SELECT a.attname
      FROM pg_constraint c
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
      WHERE c.contype = 'f' AND c.conrelid = $1::regclass
    SQL
      .squish

    def park(table, index)
      fixed = @target.exec_params(FOREIGN_COLUMNS_SQL, [table.name]).column_values(0) + table.key
      column, type = @target.exec_params(INDEX_COLUMNS_SQL, [index]).values.find do |name, kind|
        PARKING.key?(kind) && !fixed.include?(name)
      end

      raise Mismatch, "#{table.name}: rows collide on #{index} and no column of it can be parked" if column.nil?

      if PARKING[type] != PARKING["text"]
        floor = @target
          .exec("SELECT min(t.#{column}) FROM #{table.name} t JOIN content_patch p ON #{join(table, "t", "p")}")
          .getvalue(0, 0)
        raise Mismatch, "#{table.name}: #{column} holds negative values, so it cannot be parked" if floor.to_i.negative?
      end

      @target.exec(
        "UPDATE #{table.name} t SET #{column} = #{PARKING.fetch(type).call("t.#{column}")} FROM content_patch p WHERE #{join(table, "t", "p")}"
      )
    end

    def hashes(connection, table, buckets)
      sql = <<~SQL
        SELECT #{list(table.key)}, #{row_digest(table)} AS digest
        FROM #{table.name} WHERE #{table.predicate} AND #{table.bucket} / #{BUCKET} = ANY($1::bigint[])
      SQL
        .squish
      width = table.key.length
      connection.exec_params(sql, ["{#{buckets.join(",")}}"]).values.each_with_object({}) do |row, memo|
        memo[row.first(width).map(&:to_i)] = row.last
      end
    end

    def stage_keys(connection, table, keys)
      declarations = table.key.map { |name| "#{name} bigint" }.join(", ")
      connection.exec("DROP TABLE IF EXISTS content_keys")
      connection.exec("CREATE TEMP TABLE content_keys (#{declarations})")
      connection.copy_data("COPY content_keys (#{list(table.key)}) FROM STDIN") do
        keys.each { |key| connection.put_copy_data("#{key.join("\t")}\n") }
      end
    end

    def sequence(connection, table)
      connection.exec_params("SELECT pg_get_serial_sequence($1, 'id')", [table.name]).getvalue(0, 0)
    end

    def row_digest(table) = "md5(jsonb_build_array(#{list(compared(table))})::text)"

    def join(table, left, right) = table.key.map { |name| "#{left}.#{name} = #{right}.#{name}" }.join(" AND ")

    def list(names) = names.join(", ")

    def qualified(names, prefix) = names.map { |name| "#{prefix}.#{name}" }.join(", ")
  end
end
