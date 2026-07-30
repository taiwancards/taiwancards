# frozen_string_literal: true

module Lexemes
  module Facets
    CONFIG = {
      "character" => %w[recognition reading listening tone writing],
      "word" => %w[recognition production reading listening tone writing],
      "phrase" => %w[recognition reading]
    }.freeze

    DEFAULT = %w[recognition].freeze

    module_function

    AUDIO_ONLY = %w[listening].freeze

    def for(lexeme)
      override = Array(lexeme.data["facets"]) & LexemeMemory.facets.keys
      base = override.presence || CONFIG[lexeme.kind] || DEFAULT
      return base if (base & AUDIO_ONLY).empty?
      return base if Huayu::MoeAudio.for(lexeme.text).present?

      base - AUDIO_ONLY
    end
  end
end
