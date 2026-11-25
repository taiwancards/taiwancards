# frozen_string_literal: true

module Huayu
  class StandardContrasts
    DATA = JsonData.new("huayu/standard_contrasts.json")
    SECTIONS = %w[initials finals rimes blocks tones].freeze
    TONE_SLOTS = %w[t1 t2 t3 t4 neutral range merge erhua retroflex nasal].freeze
    SIDES = %w[taipei beijing].freeze

    class << self
      def for(section, key, locale = I18n.locale)
        entry = contrasts(locale).dig(section.to_s, key.to_s)
        return unless entry.is_a?(Hash)

        entry.slice(*SIDES).compact_blank.presence
      end

      def contrasts(locale = I18n.locale) = data.fetch(Locales.key(locale), {})

      def words = data.fetch("words", [])

      def data = DATA.value

      def reset! = DATA.reset!
    end
  end
end
