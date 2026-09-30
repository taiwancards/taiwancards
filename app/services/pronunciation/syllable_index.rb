# frozen_string_literal: true

module Pronunciation
  module SyllableIndex
    KEY = "pron:syllable_index:audio"

    module_function

    def for
      Rails.cache.fetch(KEY, expires_in: 12.hours) { build }
    end

    def refresh
      Rails.cache.delete(KEY)
      self.for
    end

    def lookup(key)
      self.for[key]
    end

    def build
      best = {}

      Lexeme
        .where(kind: %i[word character])
        .where("readings ->> 'pinyin' IS NOT NULL")
        .where("char_length(text) = 1")
        .find_each do |lexeme|
          syllables = target(lexeme)
          next unless syllables.length == 1

          quality = Huayu::MoeAudio.quality(lexeme.text, zhuyin: lexeme.headline_zhuyin)
          SyllableKey.candidates(syllables.first).each do |key|
            best[key] = [quality, lexeme.id] if best[key].nil? || quality < best[key].first
          end
        end

      best.transform_values(&:last)
    end

    def target(lexeme)
      Huayu::PronunciationTarget.new(lexeme).syllables
    rescue StandardError
      []
    end
  end
end
