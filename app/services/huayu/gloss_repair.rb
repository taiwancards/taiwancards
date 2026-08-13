# frozen_string_literal: true

module Huayu
  class GlossRepair
    BATCH = 500
    LOCALES = %w[en ru].freeze

    Result = Data.define(:examined, :repaired) do
      def changed? = repaired.positive?

      def to_s = "glosses normalised: #{repaired} of #{examined}"
    end

    def call
      rows = pending
      rows.each_slice(BATCH) do |slice|
        glosses = slice.to_h

        Lexeme.where(id: glosses.keys).each do |lexeme|
          lexeme.update_columns(meanings: lexeme.meanings.merge(glosses[lexeme.id]))
        end
      end

      Result.new(examined: stored.length, repaired: rows.length)
    end

    def drift? = pending.any?

    private

    def stored
      @stored ||= Lexeme.where("meanings::text ~ ?", "[\\u4e00-\\u9fff]").pluck(:id, :meanings)
    end

    def pending
      @pending ||= stored.filter_map do |id, meanings|
        fresh = repairs(meanings)
        [id, fresh] if fresh.any?
      end
    end

    def repairs(meanings)
      LOCALES
        .filter_map { |locale|
          gloss = meanings[locale].to_s
          next if gloss.empty?

          normalized = GlossText.normalize(gloss, locale:)
          [locale, normalized] if normalized != gloss
        }
        .to_h
    end
  end
end
