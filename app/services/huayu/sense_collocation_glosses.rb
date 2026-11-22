# frozen_string_literal: true

module Huayu
  class SenseCollocationGlosses
    DATA = JsonData.new("huayu/sense_collocation_glosses.json", default: {}, watch: true)

    class << self
      def gloss(text, locale = I18n.locale)
        entry = DATA.value[text]
        return nil if entry.nil?

        Locales.pick(entry, locale).presence
      end

      def reset! = DATA.reset!
    end
  end
end
