# frozen_string_literal: true

module Lexemes
  module Facets
    CONFIG = {
      "character" => %w[recognition reading listening tone writing],
      "word" => %w[recognition production reading listening tone writing],
      "phrase" => %w[recognition reading],
      "grammar" => %w[recognition],
      "sentence" => %w[listening]
    }.freeze

    DEFAULT = %w[recognition].freeze

    module_function

    AUDIO_ONLY = %w[listening].freeze

    def for(lexeme)
      override = Array(lexeme.data["facets"]) & LexemeMemory.facets.keys
      base = override.presence || CONFIG[lexeme.kind] || DEFAULT
      return base if (base & AUDIO_ONLY).empty?
      return base if voiced?(lexeme)

      base - AUDIO_ONLY
    end

    def voiced?(lexeme)
      return Huayu::ListeningClips.for_text(lexeme.text).present? if lexeme.sentence?

      Huayu::MoeAudio.for(lexeme.text, zhuyin: zhuyin_of(lexeme)).present?
    end

    def zhuyin_of(lexeme)
      lexeme.reading_set.filter_map { |reading| reading["zhuyin"].presence }.first
    end
  end
end
