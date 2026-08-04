# frozen_string_literal: true

module Huayu
  class SolarTerms
    DATA = JsonData.new("huayu/solar_terms.json", default: {"terms" => {}})

    class << self
      def date_for(term, year)
        value = terms.dig(term.to_s, year.to_s)
        value && Date.parse(value)
      end

      def source
        raw["source"]
      end

      def reset! = DATA.reset!

      private

      def terms
        raw["terms"]
      end

      def raw = DATA.value
    end
  end
end
