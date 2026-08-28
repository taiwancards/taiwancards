# frozen_string_literal: true

module Huayu
  class PlaceImporter
    PATH = AppData.path("huayu/taiwan_places.json")
    SOURCE = "Taiwan places"

    Result = Data.define(:imported, :skipped)

    def initialize(path: PATH)
      @path = Pathname(path)
      @upserter = Lexemes::Upserter.new
    end

    def call
      return Result.new(imported: 0, skipped: 0) unless @path.exist?

      imported = 0
      skipped = 0

      entries.each do |entry|
        text = entry["text"].to_s.strip
        next skipped += 1 if text.blank?

        lexeme = @upserter.word(
          text,
          readings: {"pinyin" => entry["pinyin"], "zhuyin" => entry["zhuyin"]}.compact_blank,
          meanings: {"en" => entry["en"], "ru" => entry["ru"]}.compact_blank,
          pos: "N",
          source: SOURCE
        )
        lexeme.update_column(:data, lexeme.data.merge("place" => Array(entry["belongs"])))
        imported += 1
      end

      Huayu::TextAnalyzer.reset_vocabulary!
      Result.new(imported:, skipped:)
    end

    private

    def entries
      JSON.parse(File.read(@path))
    end
  end
end
