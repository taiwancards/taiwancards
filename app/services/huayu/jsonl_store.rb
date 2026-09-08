# frozen_string_literal: true

module Huayu
  class JsonlStore
    class << self
      def path = Pathname(self::PATH)

      def fields = self::Entry.members

      def key(entry) = entry.public_send(fields.first)

      def read
        return [] unless path.exist?

        path.each_line.filter_map do |line|
          line = line.strip
          next if line.empty?

          row = JSON.parse(line)
          self::Entry.new(**fields.to_h { |field| [field, row[field.to_s]] })
        end
      end

      def index = read.each_with_object({}) { |entry, memo| memo[key(entry)] = entry }

      def append(entries)
        existing = index
        fresh = entries.reject { |entry| existing.key?(key(entry)) }
        return 0 if fresh.empty?

        write(existing.values + fresh)
        fresh.length
      end

      def write(entries)
        path.dirname.mkpath
        path.open("w") { |file| sorted(entries).each { |entry| file.puts(serialize(entry)) } }
        entries.length
      end

      def rewrite_sorted = write(read)

      private

      def sorted(entries) = entries.uniq { |entry| key(entry) }.sort_by { |entry| key(entry) }

      def serialize(entry) = JSON.generate(entry.to_h)
    end
  end
end
