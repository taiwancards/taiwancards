# frozen_string_literal: true

module Huayu
  class GrammarLessons
    PATH = AppData.path("huayu/grammar_lessons.json")
    ZHUYIN_DEFAULT_THROUGH = 2

    Example = Data.define(:zh, :en, :ru, :zhuyin, :pinyin, :sentence) do
      def translation(locale) = locale.to_s == "ru" ? ru : en

      def annotated? = zhuyin.present?
    end

    Lesson = Data.define(:id, :slug, :pattern, :level, :head, :formula, :en, :ru, :examples) do
      def title(locale) = text_for(locale, "title")

      def body(locale) = text_for(locale, "body")

      def tip(locale) = text_for(locale, "tip")

      def formula_for(locale)
        formula[locale.to_s] || formula["en"]
      end

      def zhuyin_default? = level <= ZHUYIN_DEFAULT_THROUGH

      def to_param = slug

      def heads = head.to_s.split(/[·\s]+/).reject(&:empty?)

      private

      def text_for(locale, key)
        source = locale.to_s == "ru" ? ru : en
        source[key]
      end
    end

    class << self
      def all
        payload
      end

      def levels
        payload.group_by(&:level)
      end

      def find(param)
        value = param.to_s
        payload.find { |lesson| lesson.slug == value } ||
          payload.find { |lesson| lesson.id.to_s == value } ||
          payload.find { |lesson| lesson.heads.include?(value) || lesson.pattern == value }
      end

      def search(query, limit: 6)
        needle = query.to_s.strip.downcase
        return [] if needle.empty?

        payload.select { |lesson| matches?(lesson, needle) }.first(limit)
      end

      def available? = payload.any?

      def reset!
        @payload = nil
        @mtime = nil
        GrammarMatcher.reset!
      end

      private

      def matches?(lesson, needle)
        return true if lesson.slug.include?(needle) || lesson.pattern.downcase.include?(needle)
        return true if lesson.heads.any? { |head| head.include?(needle) }
        return true if lesson.formula.values.any? { |text| text.to_s.downcase.include?(needle) }

        [lesson.en, lesson.ru].any? { |source| source["title"].to_s.downcase.include?(needle) }
      end

      def payload
        current = PATH.exist? ? PATH.mtime : nil
        if @payload && @mtime != current
          @payload = nil
          GrammarMatcher.reset!
        end

        @mtime = current
        @payload ||= load
          .map do |row|
            Lesson.new(
              id: row["id"],
              slug: row["slug"] || row["id"].to_s,
              pattern: row["pattern"],
              level: row["level"],
              head: row["head"],
              formula: row["formula"] || {},
              en: row["en"] || {},
              ru: row["ru"] || {},
              examples: Array(row["examples"]).map do |example|
                Example.new(
                  zh: example["zh"],
                  en: example["en"],
                  ru: example["ru"],
                  zhuyin: example["zhuyin"],
                  pinyin: example["pinyin"],
                  sentence: example["sentence"]
                )
              end
            )
          end
          .freeze
      end

      def load
        PATH.exist? ? JSON.parse(PATH.read) : []
      rescue JSON::ParserError
        []
      end
    end
  end
end
