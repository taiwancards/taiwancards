# frozen_string_literal: true

module Huayu
  class SentenceGlossStore
    PATH = AppData.path("huayu/sentence_glosses.jsonl")

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

      def put(text, en:, ru:)
        entries = index
        if en.blank? && ru.blank?
          entries.delete(text)
        else
          entries[text] = Entry.new(text: text, en: en.presence, ru: ru.presence)
        end

        write(entries.values)
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
            file.puts(JSON.generate({text: entry.text, en: entry.en, ru: entry.ru}))
          end
        end

        entries.length
      end
    end
  end
end
