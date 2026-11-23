# frozen_string_literal: true

module Huayu
  class EtymologyRepair
    BATCH = 500
    TEXT = "etymology_text"
    TRANSLATIONS = EtymologyTranslations::KEY

    Result = Data.define(:examined, :repaired) do
      def changed? = repaired.positive?

      def to_s = "etymology text normalized: #{repaired} of #{examined}"
    end

    def call
      ids = pending
      ids.each_slice(BATCH) do |slice|
        Lexeme.where(id: slice).each do |lexeme|
          lexeme.update_column(:data, repaired(lexeme.data))
        end
      end

      Result.new(examined: (texts.map(&:first) | translations.map(&:first)).length, repaired: ids.length)
    end

    def drift? = pending.any?

    private

    def texts
      @texts ||= Lexeme
        .where("data ? :key", key: TEXT)
        .pluck(:id, Arel.sql("data->>'#{TEXT}'"))
    end

    def translations
      @translations ||= Lexeme
        .where("data ? :key", key: TRANSLATIONS)
        .pluck(:id, Arel.sql("data->'#{TRANSLATIONS}'"))
    end

    def pending
      @pending ||= texts.filter_map { |id, text| id if EtymologyText.normalize(text) != text } |
        translations.filter_map { |id, stored| id if unlabeled(stored) != stored }
    end

    def repaired(data)
      text = EtymologyText.normalize(data[TEXT])
      stored = data[TRANSLATIONS]
      kept = unlabeled(stored)
      fixed = data.except(TEXT, TRANSLATIONS)
      fixed[TEXT] = text if data.key?(TEXT) && text.present?
      fixed[TRANSLATIONS] = kept if data.key?(TRANSLATIONS) && (kept == stored || kept.present?)
      fixed
    end

    def unlabeled(stored)
      return stored unless stored.is_a?(Hash)

      stored
        .filter_map do |locale, fields|
          next [locale, fields] unless fields.is_a?(Hash) && EtymologyText.bare_label?(fields["text"])

          rest = fields.except("text")
          [locale, rest] if rest.any?
        end
        .to_h
    end
  end
end
