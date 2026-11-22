# frozen_string_literal: true

module Huayu
  class CharacterEnricher
    PATH = AppData.path("dictionaries/makemeahanzi/dictionary.txt")
    OVERRIDES = AppData.path("huayu/etymology_structure.json")

    def initialize(path: PATH, overrides: OVERRIDES)
      @path = Pathname(path)
      @overrides_path = Pathname(overrides)
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

    def repair_overrides
      Lexeme.where(kind: :character, text: overrides.keys).count do |lexeme|
        fixed = etymology_for(lexeme.text, lexeme.data["etymology"])
        next false if fixed == lexeme.data["etymology"]

        lexeme.update!(data: lexeme.data.except("etymology").merge({"etymology" => fixed}.compact))
      end
    end

    private

    def load_index
      @path.each_line.with_object({}) do |line, index|
        data = JSON.parse(line)
        index[data["character"]] = data
      end
    end

    def overrides
      @overrides ||= @overrides_path.exist? ? JSON.parse(@overrides_path.read) : {}
    end

    def etymology_for(text, etymology)
      override = overrides[text]
      return etymology if override.nil?

      (etymology || {}).merge(override).compact.presence
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
        .merge("en" => lexeme.meanings["en"].presence || trustworthy(lexeme.text, entry["definition"]))
        .compact_blank
      backfill_reading(lexeme, entry["pinyin"])
      return false unless lexeme.changed?

      lexeme.save!
      true
    end

    def trustworthy(text, definition)
      GlossCollisions.tainted?(text) ? nil : definition
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
