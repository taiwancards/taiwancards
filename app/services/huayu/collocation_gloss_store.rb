# frozen_string_literal: true

module Huayu
  class CollocationGlossStore
    PATH = AppData.path("huayu/collocation_glosses.jsonl")

    Entry = Data.define(:text, :en, :ru)

    class << self
      def path
        Pathname(PATH)
      end

      def read
        return [] unless path.exist?

        path.each_line.filter_map do |line|
          line = line.strip
          next if line.empty?

          row = JSON.parse(line)
          Entry.new(text: row["text"], en: row["en"], ru: row["ru"])
        end
      end

      def index
        read.each_with_object({}) { |entry, memo| memo[entry.text] = entry }
      end

      def append(entries)
        existing = index
        fresh = entries.reject { |entry| existing.key?(entry.text) }
        return 0 if fresh.empty?

        path.dirname.mkpath
        path.open("a") do |file|
          fresh.each do |entry|
            file.puts(JSON.generate({text: entry.text, en: entry.en, ru: entry.ru}))
          end
        end

        fresh.length
      end

      def rewrite_sorted
        entries = read.uniq(&:text).sort_by(&:text)
        path.open("w") do |file|
          entries.each do |entry|
            file.puts(JSON.generate({text: entry.text, en: entry.en, ru: entry.ru}))
          end
        end

        entries.length
      end
    end
  end
end
