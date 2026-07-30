# frozen_string_literal: true

module Huayu
  class GlossOverrideEnricher
    PATH = AppData.path("huayu/gloss_overrides.json")

    def initialize
    end

    def call
      return {en: 0, ru: 0} unless PATH.exist?

      overrides = JSON.parse(PATH.read)
      counts = {en: 0, ru: 0}

      overrides.each_slice(500) do |slice|
        texts = slice.to_h
        Lexeme.where(text: texts.keys).find_each do |lexeme|
          data = texts[lexeme.text]
          meanings = lexeme.meanings.dup

          if meanings["en"].to_s.strip.empty? && data["en"].to_s.strip.present?
            meanings["en"] = data["en"]
            counts[:en] += 1
          end

          if meanings["ru"].to_s.strip.empty? && data["ru"].to_s.strip.present?
            meanings["ru"] = data["ru"]
            counts[:ru] += 1
          end

          lexeme.update!(meanings:) if meanings != lexeme.meanings
        end
      end

      counts
    end
  end
end
