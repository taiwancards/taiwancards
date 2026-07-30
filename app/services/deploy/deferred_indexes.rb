# frozen_string_literal: true

module Deploy
  class DeferredIndexes
    def initialize(tables, io: $stdout)
      @tables = Array(tables)
      @io = io
      @saved = []
    end

    def self.around(tables, io: $stdout, &block)
      new(tables, io: io).call(&block)
    end

    def call
      drop
      yield
    ensure
      restore
    end

    private

    def connection = ActiveRecord::Base.connection

    def droppable
      @tables.flat_map do |table|
        next [] unless connection.table_exists?(table)

        connection.indexes(table).reject { |index| index.unique }.map { |index| [table, index.name] }
      end
    end

    def drop
      droppable.each do |table, name|
        definition = connection.select_value(
          ActiveRecord::Base.sanitize_sql_array(["SELECT indexdef FROM pg_indexes WHERE indexname = ?", name])
        )
        next if definition.blank?

        @saved << definition
        connection.execute("DROP INDEX IF EXISTS #{connection.quote_table_name(name)}")
      end

      @io.puts("  indexes dropped for the load: #{@saved.length}") if @saved.any?
    end

    NAME = /CREATE (?:UNIQUE )?INDEX (\S+)/

    def restore
      return if @saved.empty?

      @io.puts("\n  rebuilding #{@saved.length} indexes")
      total = @saved.length
      @saved.each_with_index do |definition, index|
        name = definition[NAME, 1].to_s.delete("\"")
        @io.print(format("    [%d/%d] %-52s", index + 1, total, name.truncate(52)))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        connection.execute(definition)
        @io.puts(format("%6.1fs", Process.clock_gettime(Process::CLOCK_MONOTONIC) - started))
      end

      @saved = []
    end
  end
end
