# frozen_string_literal: true

module Huayu
  class CharacterProfile
    def initialize(lexeme)
      @lexeme = lexeme
    end

    attr_reader :lexeme

    def readings
      @readings ||= lexeme.reading_set
    end

    def several_readings?
      readings.size > 1
    end

    ReadingGroup = Data.define(:reading, :senses, :words)

    def reading_groups(limit: nil)
      senses = grouped_senses
      words = grouped_words
      groups = readings.map do |reading|
        key = reading["pinyin"]
        ReadingGroup.new(
          reading: reading,
          senses: senses.fetch(key, []),
          words: limit ? words.fetch(key, []).first(limit) : words.fetch(key, [])
        )
      end

      rest = words.fetch(nil, [])
      rest = rest.first(limit) if limit
      groups += [ReadingGroup.new(reading: nil, senses: [], words: rest)] if rest.any?
      groups.reject { |group| group.senses.empty? && group.words.empty? }
    end

    TOP_WORDS_LIMIT = 10

    def top_words(limit = TOP_WORDS_LIMIT)
      @top_words ||= lexeme.containing_words.visible.frequency_order.limit(limit).to_a
    end

    def grouped_senses
      all = lexeme.senses.ordered.to_a
      return {readings.first&.dig("pinyin") => all} unless several_readings?

      all.group_by(&:reading)
    end

    def grouped_words
      lexeme
        .parent_links
        .includes(:parent)
        .select { |link| link.parent.word? }
        .group_by(&:reading)
        .transform_values { |links| by_frequency(links.map(&:parent).uniq) }
    end

    def by_frequency(words)
      words.sort_by { |word| [word.data["freq_rank"] || Float::INFINITY, word.text] }
    end

    SENTENCE_LIMIT = 10

    def phrases
      @phrases ||= begin
        ids = SentenceWord.where(lexeme: lexeme).ranked.limit(SENTENCE_LIMIT).pluck(:sentence_id)
        if ids.empty?
          []
        else
          Lexeme
            .where(id: ids)
            .visible
            .includes(:content_sources, :sentence_profile)
            .sort_by { |found| ids.index(found.id) }
        end
      end
    end

    def memories
      @memories ||= lexeme.memories.owned_by(Current.user).index_by(&:facet)
    end

    def studied?
      memories.values.any? { |memory| memory.activated_at.present? }
    end

    def etymology
      lexeme.data["etymology"]
    end

    def etymology_text
      lexeme.data["etymology_text"].presence
    end

    def etymology_source
      slug = lexeme.data["etymology_source"].presence
      return nil if slug.nil?

      @etymology_source ||= ContentSource.find_by(slug: slug)
    end

    def taiwan_specific?
      lexeme.data["taiwan_specific"].present?
    end

    def radical
      lexeme.data["radical"]
    end

    def decomposition
      lexeme.data["decomposition"]
    end

    def strokes
      CnsStrokes.count(lexeme.text) || lexeme.data["strokes"]
    end

    def stroke_sequence
      CnsStrokes.strokes(lexeme.text)
    end

    def animation_diverges?
      CnsStrokes.diverges?(lexeme.text, lexeme.data["strokes"])
    end

    def moe_index
      lexeme.data["moe_index"]
    end

    def series
      @series ||= PhoneticSeries.containing(lexeme.text)
    end

    def confusable
      @confusable ||= ConfusableCharacters.for(lexeme.text)
    end

    def strokes_available?
      Huayu::StrokeData.has?(lexeme.text)
    end
  end
end
