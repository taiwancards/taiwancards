# frozen_string_literal: true

module Huayu
  class WordProfile
    def initialize(lexeme)
      @lexeme = lexeme
    end

    attr_reader :lexeme

    def readings
      @readings ||= lexeme.reading_set
    end

    def reading_label
      readings.map { |reading| reading["zhuyin"].presence || reading["pinyin"] }.compact_blank.join(" · ")
    end

    def pinyin_label
      readings.map { |reading| reading["pinyin"] }.compact_blank.join(" · ")
    end

    def components
      @components ||= lexeme.components.to_a
    end

    def component_characters
      components.select(&:character?)
    end

    def component_words
      components.select { |part| part.word? || part.collocation? }
    end

    def memories
      @memories ||= lexeme.memories.owned_by(Current.user).index_by(&:facet)
    end

    def studied?
      memories.values.any? { |memory| memory.activated_at.present? }
    end

    SENTENCE_LIMIT = 12

    EXAMPLE_ORDER = "(coalesce(btrim(lexemes.meanings ->> ?), '') = '') ASC, " \
      "sentence_profiles.difficulty ASC NULLS LAST, " \
      "sentence_words.gdex DESC, " \
      "lexemes.id ASC"

    def sentences
      @sentences ||= Lexeme
        .where(kind: :sentence)
        .visible
        .joins("JOIN sentence_words ON sentence_words.sentence_id = lexemes.id")
        .where(sentence_words: {lexeme_id: lexeme.id})
        .left_joins(:sentence_profile)
        .preload(:content_sources, :sentence_profile)
        .order(Arel.sql(Lexeme.sanitize_sql_array([EXAMPLE_ORDER, I18n.locale.to_s])))
        .limit(SENTENCE_LIMIT)
        .to_a
    end

    COLLOCATION_LIMIT = 12

    def collocations
      @collocations ||= lexeme
        .containers
        .where(kind: :collocation)
        .visible
        .curriculum_order
        .limit(COLLOCATION_LIMIT)
        .to_a
    end

    def senses
      @senses ||= lexeme.senses.includes(examples: :lexeme).to_a
    end

    def translated_senses
      @translated_senses ||= senses.select { |sense| sense.meaning(I18n.locale).present? }
    end

    def sense_reading(sense)
      return nil if sense.reading.blank? || lexeme.reading_set.size < 2

      found = lexeme.reading_set.find { |reading| reading["pinyin"] == sense.reading }
      found&.dig("zhuyin").presence || sense.reading
    end

    def show_flat_meaning?
      translated_senses.empty?
    end

    APPEARS_IN_LIMIT = 8

    def appears_in
      @appears_in ||= SenseExample
        .where(lexeme_id: lexeme.id)
        .includes(lexeme_sense: :lexeme)
        .limit(APPEARS_IN_LIMIT)
        .filter_map { |example| example.lexeme_sense }
        .select { |sense| sense.lexeme && sense.lexeme.id != lexeme.id }
        .uniq { |sense| sense.id }
    end

    REVISED_MIN_LEVEL = 3

    def sketch
      @sketch ||= WordSketch.for(lexeme.text)
    end

    def revised_senses(level: nil)
      return [] if senses.any?
      return [] if level && level < REVISED_MIN_LEVEL

      MoeRevised.for(lexeme.text).senses
    end

    def taiwan_specific?
      lexeme.data["taiwan_specific"].present?
    end

    def etymology
      lexeme.data["etymology_text"].presence
    end

    def pos
      lexeme.data["pos"]
    end

    def sources
      lexeme.sources
    end

    def tocfl_level
      @tocfl_level ||= Collection
        .where(kind: :tocfl)
        .joins(:collection_items)
        .where(collection_items: {lexeme_id: lexeme.id})
        .order(:position)
        .first
    end
  end
end
