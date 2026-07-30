# frozen_string_literal: true

module Pronunciation
  module SyllableIndex
    module_function

    def for
      Rails.cache.fetch("pron:syllable_index", expires_in: 12.hours) { build }
    end

    def lookup(key)
      self.for[key]
    end

    def build
      index = {}

      Lexeme
        .where(kind: %i[word character])
        .where("readings ->> 'pinyin' IS NOT NULL")
        .where("char_length(text) = 1")
        .find_each do |lexeme|
          syllables = target(lexeme)
          next unless syllables.length == 1

          SyllableKey.candidates(syllables.first).each { |key| index[key] ||= lexeme.id }
        end

      index
    end

    def target(lexeme)
      Huayu::PronunciationTarget.new(lexeme).syllables
    rescue StandardError
      []
    end
  end
end
