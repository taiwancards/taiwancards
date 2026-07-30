# frozen_string_literal: true

module Huayu
  class TaiwanPhrases
    PATH = AppData.path("huayu/taiwan_phrases.json")
    SLOT = /\{([^}]+)\}/
    ROLES = %w[you staff].freeze

    Scene = Data.define(:id, :zh, :domain, :position, :names) do
      def name(locale) = names[locale.to_s] || names["en"]
    end

    Option = Data.define(:text, :pinyin, :names) do
      def name(locale) = names[locale.to_s] || names["en"]
    end

    Slot = Data.define(:id, :names, :options) do
      def name(locale) = names[locale.to_s] || names["en"]

      def closed? = options.any?
    end

    Pattern = Data.define(
      :id,
      :scene,
      :role,
      :level,
      :text,
      :pinyin,
      :zhuyin,
      :links,
      :replies,
      :avoid,
      :names,
      :notes
    ) do
      def name(locale) = names[locale.to_s] || names["en"]

      def note(locale) = notes[locale.to_s] || notes["en"]

      def staff? = role == "staff"

      def parts = text.split(SLOT).each_slice(2).map { |literal, name| [literal, name] }

      def slots = text.scan(SLOT).flatten

      def literal = text.gsub(SLOT, " ")
    end

    class << self
      def scenes = payload[:scenes]

      def scene(id) = payload[:by_scene][id.to_s]

      def patterns(scene: nil, role: nil, level: nil)
        found = scene ? Array(payload[:grouped][scene.to_s]) : payload[:patterns]
        found = found.select { |pattern| pattern.role == role.to_s } if role
        found = found.select { |pattern| pattern.level <= level } if level
        found
      end

      def slot(id) = payload[:slots][id.to_s]

      def counts = payload[:counts]

      def for_lexeme(text) = Array(payload[:index][text.to_s])

      def available? = payload[:patterns].any?

      def size = payload[:patterns].length

      def reset! = @payload = nil

      private

      def payload
        @payload ||= build(load)
      end

      def load
        PATH.exist? ? JSON.parse(PATH.read) : {}
      rescue JSON::ParserError
        {}
      end

      def build(raw)
        scenes = Array(raw["scenes"]).map { |row| scene_from(row) }
        slots = Array(raw["slots"]).to_h { |row| [row["id"], slot_from(row)] }
        patterns = Array(raw["patterns"]).map { |row| pattern_from(row) }
        grouped = patterns.group_by(&:scene)

        {
          scenes: scenes.sort_by(&:position).freeze,
          by_scene: scenes.index_by(&:id).freeze,
          slots: slots.freeze,
          patterns: patterns.freeze,
          grouped: grouped.freeze,
          counts: grouped.transform_values(&:length).tap { |row| row.default = 0 }.freeze,
          index: index_for(patterns, slots).freeze
        }
      end

      def scene_from(row)
        Scene.new(
          id: row["id"],
          zh: row["zh"],
          domain: row["domain"],
          position: row["position"].to_i,
          names: row.slice("en", "ru").freeze
        )
      end

      def slot_from(row)
        Slot.new(
          id: row["id"],
          names: row.slice("en", "ru").freeze,
          options: Array(row["options"])
            .map { |option|
              Option.new(text: option["text"], pinyin: option["pinyin"], names: option.slice("en", "ru").freeze)
            }
            .freeze
        )
      end

      def pattern_from(row)
        Pattern.new(
          id: row["id"],
          scene: row["scene"],
          role: ROLES.include?(row["role"]) ? row["role"] : ROLES.first,
          level: row["level"].to_i,
          text: row["text"],
          pinyin: row["pinyin"],
          zhuyin: reading(row["pinyin"]),
          links: Array(row["links"]).freeze,
          replies: Array(row["replies"]).freeze,
          avoid: row["avoid"]&.freeze,
          names: row.slice("en", "ru").freeze,
          notes: {"en" => row["note_en"], "ru" => row["note_ru"]}.compact.freeze
        )
      end

      SPOKEN = /[^\p{Latin}\p{Mn}' ]+/

      def reading(pinyin)
        cleaned = pinyin.to_s.gsub(SPOKEN, " ").squeeze(" ").strip
        return nil if cleaned.blank?

        Zhuyin.from_pinyin(cleaned)
      end

      def index_for(patterns, slots)
        index = {}
        patterns.each do |pattern|
          keys = pattern.links.dup
          pattern.slots.each { |name| keys.concat(Array(slots[name]&.options).map(&:text)) }
          keys.uniq.each { |key| (index[key] ||= []) << pattern }
        end

        index.transform_values(&:freeze)
      end
    end
  end
end
