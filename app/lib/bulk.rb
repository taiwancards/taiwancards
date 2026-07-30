# frozen_string_literal: true

module Bulk
  SCRATCH = "bulk_patch"
  CHUNK = 50_000

  class << self
    def patch(target:, columns:, rows:, set: nil, key: "id")
      written = 0
      rows.each_slice(CHUNK) do |slice|
        next if slice.empty?

        written += apply(target, columns, slice, set, key)
      end

      written
    end

    def upsert(target:, columns:, rows:, conflict:, update: nil, key: "id")
      names = ([key] + columns.keys).join(", ")
      assignments = (update || columns.keys).map { |name| "#{name} = EXCLUDED.#{name}" }.join(", ")
      written = 0

      rows.each_slice(CHUNK) do |slice|
        next if slice.empty?

        create(columns, key)
        copy(columns, slice, key)
        written += connection.exec_update(
          "INSERT INTO #{target} (#{names}) SELECT #{names} FROM #{SCRATCH} " \
            "ON CONFLICT (#{conflict}) DO UPDATE SET #{assignments}",
          "bulk_upsert"
        )
        connection.execute("DROP TABLE IF EXISTS #{SCRATCH}")
      end

      written
    end

    private

    def apply(target, columns, rows, set, key)
      create(columns, key)
      copy(columns, rows, key)
      connection.execute("ANALYZE #{SCRATCH}")
      touched = connection.exec_update(update_sql(target, columns, set, key), "bulk_patch")
      connection.execute("DROP TABLE IF EXISTS #{SCRATCH}")
      touched
    end

    def create(columns, key)
      declarations = columns.map { |name, type| "#{name} #{type}" }.join(", ")
      connection.execute("DROP TABLE IF EXISTS #{SCRATCH}")
      connection.execute("CREATE UNLOGGED TABLE #{SCRATCH} (#{key} bigint PRIMARY KEY, #{declarations})")
    end

    def copy(columns, rows, key)
      names = ([key] + columns.keys).join(", ")
      raw = connection.raw_connection
      raw.copy_data("COPY #{SCRATCH} (#{names}) FROM STDIN") do
        rows.each { |row| raw.put_copy_data("#{row.map { |value| encode(value) }.join("\t")}\n") }
      end
    end

    ESCAPES = {"\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r"}.freeze

    def encode(value)
      case value
      when nil
        "\\N"
      when true
        "t"
      when false
        "f"
      when Array
        encode("{#{value.join(",")}}")
      when Hash
        encode(JSON.generate(value))
      when Numeric
        value.to_s
      when Time, DateTime
        value.utc.iso8601(6)
      else
        value.to_s.gsub(/[\\\t\n\r]/, ESCAPES)
      end
    end

    def update_sql(target, columns, set, key)
      assignments = set || columns.keys.map { |name| "#{name} = #{SCRATCH}.#{name}" }.join(", ")
      "UPDATE #{target} SET #{assignments} FROM #{SCRATCH} WHERE #{target}.#{key} = #{SCRATCH}.#{key}"
    end

    def connection = ActiveRecord::Base.connection
  end
end
