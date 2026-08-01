# frozen_string_literal: true

module Huayu
  class RejectStore
    REASONS = %w[fragment ambiguous garbled off_corpus].freeze

    Entry = Data.define(:text, :reason, :note, :en, :ru) do
      def initialize(text:, reason:, note: nil, en: nil, ru: nil)
        super
      end
    end

    class << self
      def path
        Pathname(self::PATH)
      end

      def read
        return [] unless path.exist?

        path.each_line.filter_map do |line|
          line = line.strip
          next if line.empty?

          row = JSON.parse(line)
          Entry.new(text: row["text"], reason: row["reason"], note: row["note"], en: row["en"], ru: row["ru"])
        end
      end

      def index
        read.each_with_object({}) { |entry, memo| memo[entry.text] = entry }
      end

      def texts
        read.map(&:text).to_set
      end

      def append(entries)
        existing = index
        fresh = entries.reject { |entry| existing.key?(entry.text) }
        return 0 if fresh.empty?

        write(existing.values + fresh)
        fresh.length
      end

      def write(entries)
        path.dirname.mkpath
        path.open("w") do |file|
          entries.uniq(&:text).sort_by(&:text).each do |entry|
            file.puts(
              JSON.generate(
                {text: entry.text, reason: entry.reason, note: entry.note, en: entry.en, ru: entry.ru}.compact
              )
            )
          end
        end

        entries.length
      end
    end
  end
end
