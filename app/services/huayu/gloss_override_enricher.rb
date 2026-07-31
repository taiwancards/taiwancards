# frozen_string_literal: true

module Huayu
  class GlossOverrideEnricher
    PATH = AppData.path("huayu/gloss_overrides.json")

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return {en: 0, ru: 0, replaced_en: 0, replaced_ru: 0} unless @path.exist?

      overrides = JSON.parse(@path.read)
      counts = {en: 0, ru: 0, replaced_en: 0, replaced_ru: 0}

      overrides.each_slice(500) do |slice|
        texts = slice.to_h
        Lexeme.where(text: texts.keys).find_each do |lexeme|
          data = texts[lexeme.text]
          meanings = lexeme.meanings.dup

          %w[en ru].each do |locale|
            fresh = data[locale].to_s.strip
            next if fresh.empty?

            current = meanings[locale].to_s.strip
            next if current == fresh
            next if current.present? && !data["replace"]

            meanings[locale] = fresh
            counts[current.empty? ? locale.to_sym : :"replaced_#{locale}"] += 1
          end

          lexeme.update!(meanings:) if meanings != lexeme.meanings
        end
      end

      counts
    end
  end
end
