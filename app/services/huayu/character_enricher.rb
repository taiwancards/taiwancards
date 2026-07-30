# frozen_string_literal: true

module Huayu
  class CharacterEnricher
    PATH = AppData.path("dictionaries/makemeahanzi/dictionary.txt")

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return 0 unless @path.exist?

      index = load_index
      count = 0
      Lexeme.where(kind: :character).find_each do |lexeme|
        entry = index[lexeme.text]
        next if entry.nil?

        count += 1 if enrich(lexeme, entry)
      end

      count
    end

    private

    def load_index
      @path.each_line.with_object({}) do |line, index|
        data = JSON.parse(line)
        index[data["character"]] = data
      end
    end

    ETYMOLOGY_OVERRIDES = {
      "捨" => {"semantic" => "扌", "phonetic" => "舍"},
      "這" => {"semantic" => "辶", "phonetic" => "言"}
    }.freeze

    def etymology_for(text, etymology)
      override = ETYMOLOGY_OVERRIDES[text]
      return etymology if override.nil? || etymology.nil?

      etymology.merge(override)
    end

    def enrich(lexeme, entry)
      lexeme.data = lexeme
        .data
        .merge(
          "radical" => entry["radical"],
          "decomposition" => entry["decomposition"],
          "etymology" => etymology_for(lexeme.text, entry["etymology"])
        )
        .compact
      lexeme.meanings = lexeme
        .meanings
        .merge("en" => lexeme.meanings["en"].presence || entry["definition"])
        .compact_blank
      backfill_reading(lexeme, entry["pinyin"])
      return false unless lexeme.changed?

      lexeme.save!
      true
    end

    def backfill_reading(lexeme, pinyin)
      return if lexeme.reading_set.any? || pinyin.blank?

      lexeme.readings = reading_entry(pinyin.first)
      lexeme.data = lexeme.data.merge("readings" => pinyin.map { |value| reading_entry(value) })
    end

    def reading_entry(pinyin)
      {"pinyin" => pinyin, "zhuyin" => Huayu::Zhuyin.from_pinyin(pinyin)}.compact_blank
    end
  end
end
