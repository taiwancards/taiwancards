# frozen_string_literal: true

module Huayu
  class EtymologyRepair
    BATCH = 500

    Result = Data.define(:examined, :repaired) do
      def changed? = repaired.positive?

      def to_s = "etymology text normalised: #{repaired} of #{examined}"
    end

    def call
      rows = pending
      rows.each_slice(BATCH) do |slice|
        texts = slice.to_h

        Lexeme.where(id: texts.keys).each do |lexeme|
          lexeme.update_column(:data, lexeme.data.merge("etymology_text" => texts[lexeme.id]))
        end
      end

      Result.new(examined: stored.length, repaired: rows.length)
    end

    def drift? = pending.any?

    private

    def stored
      @stored ||= Lexeme
        .where("data ? :key", key: "etymology_text")
        .pluck(:id, Arel.sql("data->>'etymology_text'"))
    end

    def pending
      @pending ||= stored.filter_map do |id, text|
        normalized = EtymologyText.normalize(text)
        [id, normalized] if normalized != text
      end
    end
  end
end
