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

    Line = Data.define(:zh, :names) do
      def name(locale) = names[locale.to_s].presence || names["en"]
    end

    Choice = Data.define(:zh, :names, :correct, :why, :note) do
      def name(locale) = names[locale.to_s].presence || names["en"]

      def correct? = correct

      def why_for(locale) = why[locale.to_s].presence || why["en"]

      def note_for(locale) = note[locale.to_s].presence || note["en"]
    end

    Step = Data.define(:says, :goal, :choices) do
      def goal_for(locale) = goal && (goal[locale.to_s].presence || goal["en"])

      def choice? = choices.any?
    end

    Dialogue = Data.define(:scene, :partner, :titles, :settings, :steps) do
      def title(locale) = titles[locale.to_s].presence || titles["en"]

      def setting(locale) = settings[locale.to_s].presence || settings["en"]

      def chinese = steps.flat_map { |step| [step.says&.zh, *step.choices.map(&:zh)] }.compact

      def questions = steps.count(&:choice?)
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

      def dialogue(scene) = payload[:dialogues][scene.to_s]

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
          index: index_for(patterns, slots).freeze,
          dialogues: Array(raw["dialogues"]).to_h { |row| [row["scene"], dialogue_from(row)] }.freeze
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

      def dialogue_from(row)
        Dialogue.new(
          scene: row["scene"],
          partner: line_from(row["partner"]),
          titles: Hash(row["title"]).freeze,
          settings: Hash(row["setting"]).freeze,
          steps: Array(row["steps"]).map { |step| step_from(step) }.freeze
        )
      end

      def step_from(row)
        Step.new(
          says: row["says"] && line_from(row["says"]),
          goal: row["goal"]&.freeze,
          choices: Array(row["choices"]).map { |choice| choice_from(choice) }.freeze
        )
      end

      def choice_from(row)
        Choice.new(
          zh: row["zh"],
          names: row.slice("en", "ru").freeze,
          correct: row["correct"] == true,
          why: Hash(row["why"]).freeze,
          note: Hash(row["note"]).freeze
        )
      end

      def line_from(row) = Line.new(zh: row["zh"], names: row.slice("en", "ru").freeze)

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
