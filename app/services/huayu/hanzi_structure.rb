# frozen_string_literal: true

module Huayu
  class HanziStructure
    DATA = JsonData.new("huayu/hanzi_structure.json")

    class << self
      def categories = raw["categories"] || []

      def semantics = raw["semantics"] || []

      def series = raw["series"] || []

      def walkthroughs = raw["walkthroughs"] || []

      def strokes_basic = raw["strokes_basic"] || []

      def strokes_compound = raw["strokes_compound"] || []

      def yongzi = raw["yongzi"] || []

      def order_rules = raw["order_rules"] || []

      def any? = categories.any?

      def note(key, locale = I18n.locale)
        row = Array(raw["notes"]).find { |item| item["key"] == key.to_s }
        return nil if row.nil?

        text(row, locale)
      end

      def text(row, locale = I18n.locale) = Locales.pick(row, locale)

      def name(row, locale = I18n.locale) = localized(row, "name", locale)

      def note_for(row, locale = I18n.locale) = localized(row, "note", locale)

      def reset! = DATA.reset!

      private

      def localized(row, field, locale)
        return nil if row.nil?

        row["#{locale}_#{field}"].presence || row["#{Locales::DEFAULT}_#{field}"].presence
      end

      def raw = DATA.value
    end
  end
end
