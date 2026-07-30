# frozen_string_literal: true

module Huayu
  class SolarTerms
    DATA_PATH = AppData.path("huayu/solar_terms.json")

    class << self
      def date_for(term, year)
        value = terms.dig(term.to_s, year.to_s)
        value && Date.parse(value)
      end

      def source
        raw["source"]
      end

      def reset!
        @raw = nil
      end

      private

      def terms
        raw["terms"]
      end

      def raw
        @raw ||= begin
          JSON.parse(File.read(DATA_PATH))
        rescue Errno::ENOENT, JSON::ParserError => e
          Rails.logger.error("solar terms data unavailable at #{DATA_PATH}: #{e.class}: #{e.message}")
          {"terms" => {}}
        end
      end
    end
  end
end
