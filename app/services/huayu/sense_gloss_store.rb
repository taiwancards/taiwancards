# frozen_string_literal: true

module Huayu
  class SenseGlossStore
    PATH = AppData.path("huayu/sense_glosses.jsonl")

    Entry = Data.define(:word, :zh, :en, :ru)

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
          Entry.new(word: row["word"], zh: row["zh"], en: row["en"], ru: row["ru"])
        end
      end

      def index
        read.each_with_object({}) { |entry, memo| memo[[entry.word, entry.zh]] = entry }
      end

      def append(entries)
        existing = index
        fresh = entries.reject { |entry| existing.key?([entry.word, entry.zh]) }
        return 0 if fresh.empty?

        path.dirname.mkpath
        path.open("a") do |file|
          fresh.each do |entry|
            file.puts(JSON.generate({word: entry.word, zh: entry.zh, en: entry.en, ru: entry.ru}))
          end
        end

        fresh.length
      end

      def rewrite_sorted
        entries = read.uniq { |entry| [entry.word, entry.zh] }.sort_by { |entry| [entry.word, entry.zh] }
        path.open("w") do |file|
          entries.each do |entry|
            file.puts(JSON.generate({word: entry.word, zh: entry.zh, en: entry.en, ru: entry.ru}))
          end
        end

        entries.length
      end
    end
  end
end
