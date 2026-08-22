# frozen_string_literal: true

module Huayu
  module LessonData
    module Localised
      def pick(source, locale)
        return nil if source.blank?

        source[locale.to_s].presence || source["en"]
      end
    end

    include Localised

    def lessons = payload[:lessons]
    def available? = lessons.any?
    def find(param) = payload[:by_slug][param.to_s]

    def neighbours(lesson, rows = lessons)
      position = rows.index(lesson)
      return [nil, nil] if position.nil?

      [position.positive? ? rows[position - 1] : nil, rows[position + 1]]
    end

    def reset!
      self::DATA.reset!
      remove_instance_variable(:@payload) if defined?(@payload)
      remove_instance_variable(:@raw) if defined?(@raw)
    end

    private

    def slug_index(rows) = rows.index_by(&:to_param)
    def payload
      raw = self::DATA.value
      return @payload if defined?(@payload) && @raw.equal?(raw)

      @raw = raw
      @payload = build(raw)
    end
  end
end
