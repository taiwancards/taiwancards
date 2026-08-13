# frozen_string_literal: true

module Huayu
  class EtymologyTranslations
    PATH = AppData.path("huayu/etymology_ru.json")
    KEY = "etymology_i18n"
    LOCALE = "ru"
    FIELDS = %w[hint text].freeze
    SLICE = 500

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      counts = {written: 0, unchanged: 0}
      entries.each_slice(SLICE) do |slice|
        wanted = slice.to_h
        Lexeme.where(kind: :character, text: wanted.keys).find_each do |lexeme|
          counts[apply(lexeme, wanted.fetch(lexeme.text))] += 1
        end
      end

      counts[:entries] = entries.size
      counts
    end

    def drift? = entries.any? { |text, fields| stale?(text, fields) }

    private

    def entries
      @entries ||= JSON.parse(@path.exist? ? @path.read : "{}").filter_map do |text, fields|
        kept = fields.slice(*FIELDS).transform_values { |value| value.to_s.strip }.compact_blank
        [text, kept] if kept.any?
      end
    end

    def stale?(text, fields)
      lexeme = Lexeme.find_by(kind: :character, text: text)
      lexeme.present? && translations(lexeme) != fields
    end

    def apply(lexeme, fields)
      return :unchanged if translations(lexeme) == fields

      carried = lexeme.data[KEY].is_a?(Hash) ? lexeme.data[KEY] : {}
      lexeme.update!(data: lexeme.data.merge(KEY => carried.merge(LOCALE => fields)))
      :written
    end

    def translations(lexeme) = lexeme.data.dig(KEY, LOCALE) || {}
  end
end
