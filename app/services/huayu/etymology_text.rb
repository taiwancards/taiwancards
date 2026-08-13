# frozen_string_literal: true

module Huayu
  module EtymologyText
    PLACEHOLDER = /^\(please add [^)]*\)$\n?/

    WORDING = [
      [/\bthe Mainland Mandarin\b/, "China's Mandarin"],
      [/\bMainland Mandarin\b/, "Mandarin in China"],
      [/\bMainland slang senses\b/, "slang senses in China"],
      [/\bMainland Chinese\b/, "Chinese"],
      [/\b[Mm]ainland China\b/, "China"],
      [/\bthe [Mm]ainland\b/, "China"]
    ].freeze

    module_function

    def normalize(text)
      body = TraditionalOnly.normalize(text)
      return body if body.empty?

      body = WORDING.reduce(body) { |carry, (pattern, wording)| carry.gsub(pattern, wording) }
      body.gsub(PLACEHOLDER, "").rstrip
    end
  end
end
