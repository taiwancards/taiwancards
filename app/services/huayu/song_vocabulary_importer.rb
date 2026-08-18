# frozen_string_literal: true

module Huayu
  class SongVocabularyImporter
    PATH = AppData.path("huayu/song_vocabulary.json")
    SOURCE = "Song vocabulary"

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
        if importable?(entry)
          import(entry)
          imported += 1
        else
          skipped += 1
        end
      end

      Huayu::TextAnalyzer.reset_vocabulary! if imported.positive?
      Result.new(imported:, skipped:)
    end

    private

    def entries
      JSON.parse(@path.read)
    end

    def importable?(entry)
      text = entry["text"].to_s
      return false if text.blank? || entry["en"].blank? || entry["zhuyin"].blank?

      Huayu::TraditionalOnly.simplified(text).empty? && Huayu::ChinaGuard.offender(text).nil?
    end

    def import(entry)
      lexeme = @upserter.word(
        entry["text"].to_s.strip,
        readings: {"pinyin" => entry["pinyin"], "zhuyin" => entry["zhuyin"]}.compact_blank,
        meanings: {"en" => entry["en"], "ru" => entry["ru"]}.compact_blank,
        pos: entry["pos"].presence,
        source: SOURCE
      )
      link_characters(lexeme)
      lexeme
    end

    def link_characters(lexeme)
      children = lexeme.text.chars.filter_map { |char|
        Lexeme.find_by(kind: Lexeme.kinds[:character], text: char)
      }
      @upserter.link(lexeme, children) if children.size == lexeme.text.chars.size
    end
  end
end
