# frozen_string_literal: true

module Huayu
  class RegionalNotes
    DATA = JsonData.new("huayu/regional_notes.json")
    SECTIONS = %w[initials finals rimes blocks tones grammar particles].freeze
    TONE_SLOTS = %w[reference cannot cumulative t1 t3 t4 low fourth retroflex nasal].freeze

    class << self
      def for(section, key, locale = I18n.locale)
        notes(locale).dig(section.to_s, key.to_s).presence
      end

      def notes(locale = I18n.locale) = data.fetch(Locales.key(locale), {})

      def data = DATA.value

      def reset! = DATA.reset!
    end
  end
end
