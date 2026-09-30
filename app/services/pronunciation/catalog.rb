# frozen_string_literal: true

module Pronunciation
  class Catalog
    KEY = "pron:catalog"
    PINYIN = Arel.sql("readings ->> 'pinyin'")
    ZHUYIN = Arel.sql("COALESCE(NULLIF(data #>> '{readings,0,zhuyin}', ''), readings ->> 'zhuyin')")

    class << self
      def entries = Rails.cache.fetch(key) { new.entries }

      def refresh
        Rails.cache.delete(key)
        entries
      end

      def key = "#{KEY}:#{Huayu::MoeAudio.stamp}:#{Drills.instance.stamp}"

      def features(syllables)
        syllables.flat_map do |syllable|
          key = SyllableKey.candidates(syllable).first
          initial, medial, final = Parts.split(syllable["zhuyin"])
          ["s:#{key}", "t:#{syllable["tone"]}", "i:#{initial}", ("m:#{medial}" if medial), "f:#{final}"].compact
        end
      end
    end

    def initialize(drills: Drills.instance, audio: Huayu::MoeAudio)
      @drills = drills
      @audio = audio
    end

    def entries
      return [] unless @drills.available?

      rows
        .filter_map { |id, text, pinyin, zhuyin| entry(id, text, pinyin, zhuyin) }
        .each_with_index
        .sort_by { |entry, index| [entry[:audio], index] }
        .map(&:first)
    end

    private

    def rows
      Lexeme
        .where(kind: :word)
        .where("readings ->> 'pinyin' IS NOT NULL")
        .order(:score, :id)
        .pluck(:id, :text, PINYIN, ZHUYIN)
    end

    def entry(id, text, pinyin, zhuyin)
      audio = @audio.quality(text, zhuyin:)
      return nil if audio == Huayu::MoeAudio::ABSENT

      syllables = syllables_of(text, pinyin)
      return nil if syllables.empty? || !syllables.all? { |syllable| approved?(syllable) }

      {id:, audio:, features: self.class.features(syllables)}
    end

    def syllables_of(text, pinyin)
      Huayu::TextReading.rows(text, Huayu::TextReading.headline(pinyin))
    rescue StandardError
      []
    end

    def approved?(syllable) = SyllableKey.candidates(syllable).any? { |key| @drills.approves?(key) }
  end
end
