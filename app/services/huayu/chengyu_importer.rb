# frozen_string_literal: true

module Huayu
  class ChengyuImporter
    MOE_PATH = AppData.path("huayu/moe_idioms.json")
    CURATED_PATH = AppData.path("huayu/chengyu.json")

    TONES = %w[positive neutral negative].freeze
    KINDS = %w[classic colloquial].freeze
    SOURCE_TAG = "moe_idioms"

    def initialize(io: $stdout)
      @io = io
    end

    def call
      classic = import_classic
      colloquial = mark_colloquial
      curated = apply_curated
      @io.puts(
        format(
          "成語: classical %d, colloquial %d, curated %d",
          classic,
          colloquial,
          curated
        )
      )
      {classic:, colloquial:, curated:}
    end

    private

    def import_classic
      return 0 unless MOE_PATH.exist?

      payload = JSON.parse(MOE_PATH.read)
      entries = payload["entries"] || {}
      known = existing_index(entries.keys)

      entries.count do |text, row|
        lexeme = known[text] || create(text, row)
        write(lexeme, classic_attributes(row), readings: readings_for(row))
      end
    end

    def classic_attributes(row)
      {
        "chengyu" => true,
        "chengyu_kind" => "classic",
        "chengyu_tone" => TONES.include?(row["tone"]) ? row["tone"] : "neutral",
        "chengyu_source" => row["source"].presence,
        "chengyu_gloss" => row["gloss"].presence,
        "chengyu_story" => row["story"].presence,
        "chengyu_category" => row["category"].presence,
        "chengyu_examples" => row["examples"].presence,
        "chengyu_synonyms" => row["synonyms"].presence,
        "chengyu_antonyms" => row["antonyms"].presence
      }.compact
    end

    def mark_colloquial
      colloquial_scope.count do |lexeme|
        write(lexeme, {"chengyu" => true, "chengyu_kind" => "colloquial"})
      end
    end

    def colloquial_scope
      Lexeme
        .where(kind: Lexeme::DICTIONARY_KINDS)
        .where("char_length(lexemes.text) = 4")
        .where("lexemes.meanings ->> 'en' ILIKE ?", "%(idiom%")
        .where("lexemes.data ->> 'chengyu_kind' IS DISTINCT FROM 'classic'")
    end

    def apply_curated
      return 0 unless CURATED_PATH.exist?

      rows = JSON.parse(CURATED_PATH.read)
      known = existing_index(rows.keys)

      rows.count do |text, row|
        lexeme = known[text] || create(text, row)
        write(lexeme, curated_attributes(lexeme, row), meanings: curated_meanings(row), readings: readings_for(row))
      end
    end

    def curated_attributes(lexeme, row)
      {
        "chengyu" => true,
        "chengyu_kind" => lexeme.data["chengyu_kind"].presence || "colloquial",
        "chengyu_tone" => TONES.include?(row["tone"]) ? row["tone"] : "neutral",
        "chengyu_note" => {"en" => row["note_en"], "ru" => row["note_ru"]}.compact_blank.presence,
        "chengyu_origin" => {"en" => row["origin_en"], "ru" => row["origin_ru"]}.compact_blank.presence,
        "chengyu_example" => {
          "zh" => row["example_zh"],
          "en" => row["example_en"],
          "ru" => row["example_ru"]
        }.compact_blank.presence
      }.compact
    end

    def curated_meanings(row)
      {"en" => row["en"], "ru" => row["ru"]}.compact_blank
    end

    def existing_index(texts)
      index = {}
      texts.each_slice(500) do |slice|
        Lexeme.where(kind: Lexeme::DICTIONARY_KINDS, text: slice).each do |lexeme|
          index[lexeme.text] = lexeme unless index[lexeme.text]&.word?
        end
      end

      index
    end

    def create(text, row)
      Lexeme.create!(
        kind: :collocation,
        text: text,
        readings: readings_for(row),
        meanings: {},
        data: {},
        sources: [SOURCE_TAG]
      )
    end

    def readings_for(row)
      pinyin = row["pinyin"].to_s.strip
      zhuyin = row["zhuyin"].to_s.strip.presence || (pinyin.present? ? Huayu::Zhuyin.from_pinyin(pinyin) : nil)
      {"pinyin" => pinyin.presence, "zhuyin" => zhuyin.presence}.compact
    end

    def write(lexeme, attributes, meanings: nil, readings: nil)
      lexeme.readings = readings.merge(lexeme.readings.compact_blank) if readings.present?
      lexeme.data = lexeme.data.merge(attributes)
      if meanings.present?
        lexeme.meanings = lexeme.meanings.merge(meanings) { |_key, old, fresh| fresh.presence || old }
      end

      lexeme.changed? ? lexeme.save! : true
    end
  end
end
