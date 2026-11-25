# frozen_string_literal: true

module Huayu
  class KanjiBridge
    CHARACTERS_PATH = AppData.path("huayu/japanese_bridge.json")
    WORDS_PATH = AppData.path("huayu/ja_word_bridge.json")
    RELATIONS = %w[same differs unused].freeze
    WORD_KINDS = %w[same shift new].freeze
    RULE = 0.9
    LEVELS = 1..7

    Character = Data.define(:text, :jp, :relation, :on, :pattern, :small, :level) do
      def same? = relation == "same"

      def differs? = relation == "differs"

      def unused? = relation == "unused"

      def small? = small == true
    end

    Pattern = Data.define(:id, :from, :to, :small, :members) do
      def small? = small == true
    end

    Word = Data.define(:text, :kind, :jp, :note) do
      def shift? = kind == "shift"
    end

    class << self
      def character(text) = characters[text.to_s]

      def pattern(id) = patterns_by_id[id.to_s]

      def patterns = table.fetch(:patterns)

      def counts = table.fetch(:counts)

      def readings = table.fetch(:readings)

      def available? = characters.any?

      def word(text) = words[text.to_s]

      def words_of(kind) = words_by_kind.fetch(kind.to_s, [])

      def word_texts(kind) = words_of(kind).map(&:text)

      def words_available? = words.any?

      def entries(level: nil)
        level.nil? ? characters.values : characters.values.select { |entry| entry.level == level }
      end

      def patterns_at(level: nil)
        return patterns if level.nil?

        patterns.filter_map do |pattern|
          members = pattern.members.select { |member| character(member)&.level == level }
          pattern.with(members:) if members.any?
        end
      end

      def unused(level: nil)
        entries(level:).select { |entry| entry.unused? && entry.level }
      end

      def singletons(level: nil)
        entries(level:).select { |entry| entry.differs? && entry.pattern.nil? && !entry.small? }
      end

      def small_print(level: nil)
        entries(level:).select { |entry| entry.differs? && entry.pattern.nil? && entry.small? }
      end

      def reliable?(share) = share.to_f >= RULE

      def reset!
        @table = nil
        @patterns_by_id = nil
        @words = nil
        @words_by_kind = nil
      end

      private

      def characters = table.fetch(:characters)

      def patterns_by_id
        @patterns_by_id ||= patterns.index_by(&:id).freeze
      end

      def table
        @table ||= build(load(CHARACTERS_PATH, {}))
      end

      def build(payload)
        characters = payload.fetch("characters", {}).to_h do |text, entry|
          [text, character_from(text, entry)]
        end

        {
          characters: characters.freeze,
          patterns: Array(payload["patterns"]).map { |row| pattern_from(row) }.freeze,
          counts: payload.fetch("counts", {}).freeze,
          readings: payload.fetch("readings", {}).freeze
        }.freeze
      end

      def character_from(text, entry)
        Character.new(
          text:,
          jp: entry["jp"],
          relation: entry["relation"].presence_in(RELATIONS) || "unused",
          on: entry["on"],
          pattern: entry["pattern"],
          small: entry["small"] == true,
          level: entry["level"]
        )
      end

      def pattern_from(row)
        Pattern.new(
          id: row["id"].to_s,
          from: row["from"].to_s,
          to: row["to"],
          small: row["small"] == true,
          members: Array(row["members"]).freeze
        )
      end

      def words
        @words ||= load(WORDS_PATH, {})
          .filter_map { |text, entry|
            next unless entry.is_a?(Hash)

            kind = entry["kind"].to_s.presence_in(WORD_KINDS)
            next if kind.nil?

            [text, Word.new(text:, kind:, jp: entry["jp"].presence, note: entry["note"].presence)]
          }
          .to_h
          .freeze
      end

      def words_by_kind
        @words_by_kind ||= words.values.group_by(&:kind).freeze
      end

      def load(path, fallback)
        return fallback unless path.exist?

        parsed = JSON.parse(path.read)
        parsed.is_a?(Hash) ? parsed : fallback
      rescue JSON::ParserError
        fallback
      end
    end
  end
end
