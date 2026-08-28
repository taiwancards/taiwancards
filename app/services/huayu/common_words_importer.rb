# frozen_string_literal: true

module Huayu
  class CommonWordsImporter
    PATH = AppData.path("huayu/common_words.json")
    SOURCE = "Common words"

    Result = Data.define(:imported, :skipped, :written)

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return Result.new(imported: 0, skipped: 0, written: 0) unless @path.exist?

      rows = entries.map { |entry| build(entry) }
      written = Lexemes::BulkUpserter.new.call(rows.compact)

      Huayu::TextAnalyzer.reset_vocabulary!
      Result.new(
        imported: rows.count(&:itself),
        skipped: rows.count(&:nil?),
        written: written.inserted + written.updated
      )
    end

    private

    def build(entry)
      text = entry["text"].to_s.strip
      return if text.blank?

      Lexemes::BulkUpserter::Entry.new(
        kind: :word,
        text:,
        readings: {"pinyin" => entry["pinyin"], "zhuyin" => entry["zhuyin"]}.compact_blank,
        meanings: {"en" => entry["en"], "ru" => entry["ru"]}.compact_blank,
        data: {"evidence" => {"moe" => entry["moe"], "corpus" => entry["corpus"]}.compact},
        source: SOURCE
      )
    end

    def entries
      JSON.parse(File.read(@path))
    end
  end
end
