# frozen_string_literal: true

module Huayu
  class EtymologyTranslations
    PATH = AppData.path("huayu/etymology_ru.json")
    SOURCES = [
      {path: PATH, locale: "ru", kind: :character},
      {path: AppData.path("huayu/etymology_vi.json"), locale: "vi", kind: :character},
      {path: AppData.path("huayu/etymology_de.json"), locale: "de", kind: :character},
      {path: AppData.path("huayu/etymology_ind.json"), locale: "id", kind: :character},
      {path: AppData.path("huayu/etymology_ja.json"), locale: "ja", kind: :character},
      {path: AppData.path("huayu/etymology_en.json"), locale: "en", kind: :character},
      {path: AppData.path("huayu/word_etymology_vi.json"), locale: "vi", kind: :word},
      {path: AppData.path("huayu/word_etymology_de.json"), locale: "de", kind: :word},
      {path: AppData.path("huayu/word_etymology_ind.json"), locale: "id", kind: :word},
      {path: AppData.path("huayu/word_etymology_ja.json"), locale: "ja", kind: :word},
      {path: AppData.path("huayu/word_etymology_en.json"), locale: "en", kind: :word},
      {path: AppData.path("huayu/word_etymology_ru.json"), locale: "ru", kind: :word}
    ].freeze
    KEY = "etymology_i18n"
    FIELDS = %w[hint text].freeze
    KINDS = {word: %i[word collocation]}.freeze
    SLICE = 500

    def self.call_all
      SOURCES.to_h { |source| [Pathname(source[:path]).basename.to_s, new(**source).call] }
    end

    def self.translated(lexeme, field, locale = I18n.locale)
      stored = lexeme&.data&.[](KEY)
      return nil unless stored.is_a?(Hash)

      Locales.pick(stored.transform_values { |fields| fields[field] }, locale).presence
    end

    def self.withheld?(lexeme, field)
      lexeme&.data&.dig(KEY, Locales::DEFAULT, field) == ""
    end

    def self.localized?(lexeme, locale = I18n.locale)
      key = Locales.key(locale)
      key != Locales::DEFAULT && FIELDS.any? { |field| lexeme&.data&.dig(KEY, key, field).present? }
    end

    def initialize(path: PATH, locale: "ru", kind: :character)
      @path = Pathname(path)
      @locale = Locales.key(locale)
      @kind = kind
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      counts = {written: 0, unchanged: 0}
      entries.each_slice(SLICE) do |slice|
        wanted = slice.to_h
        Lexeme.where(kind: kinds, text: wanted.keys).find_each do |lexeme|
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
        kept = fields
          .slice(*FIELDS)
          .compact
          .transform_values { |value| value.to_s.strip }
          .reject { |_field, value| EtymologyText.bare_label?(value) }
        [text, kept] if kept.any?
      end
    end

    def kinds = KINDS.fetch(@kind, @kind)

    def stale?(text, fields)
      Lexeme.where(kind: kinds, text: text).any? { |lexeme| translations(lexeme) != fields }
    end

    def apply(lexeme, fields)
      return :unchanged if translations(lexeme) == fields

      carried = lexeme.data[KEY].is_a?(Hash) ? lexeme.data[KEY] : {}
      lexeme.update!(data: lexeme.data.merge(KEY => carried.merge(@locale => fields)))
      :written
    end

    def translations(lexeme) = lexeme.data.dig(KEY, @locale) || {}
  end
end
