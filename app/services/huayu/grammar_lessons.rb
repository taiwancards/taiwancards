# frozen_string_literal: true

module Huayu
  class GrammarLessons
    DATA = JsonData.new("huayu/grammar_lessons.json", default: [], watch: true)

    Example = Data.define(:zh, :en, :ru, :zhuyin, :pinyin, :sentence, :segments) do
      def translation(locale) = locale.to_s == "ru" ? ru : en

      def annotated? = zhuyin.present?

      def syllables = zhuyin.to_s.split(/[[:space:]]+/).reject(&:empty?)
    end

    Lesson = Data.define(
      :id,
      :slug,
      :pattern,
      :level,
      :head,
      :formula,
      :en,
      :ru,
      :examples,
      :excluded,
      :supplementary,
      :glossary
    ) do
      def excluded? = excluded.present?

      def supplementary? = supplementary.present?

      def reading(run) = glossary[run]

      def exclusion_reason(locale)
        return nil if excluded.blank?

        excluded[locale.to_s == "ru" ? "reason_ru" : "reason_en"]
      end

      def title(locale) = text_for(locale, "title")

      def body(locale) = text_for(locale, "body")

      def tip(locale) = text_for(locale, "tip")

      def formula_for(locale)
        formula[locale.to_s] || formula["en"]
      end

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

      def taught
        payload.reject(&:excluded?)
      end

      def levels
        taught.group_by(&:level)
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

      def for_form(text)
        form = text.to_s
        return [] if form.empty?

        by_form.fetch(form, [])
      end

      def reset!
        DATA.reset!
        remove_instance_variable(:@payload) if defined?(@payload)
        @rows = nil
        @by_form = nil
      end

      private

      def by_form
        payload
        @by_form ||= taught.each_with_object(Hash.new { |memo, key| memo[key] = [] }) do |lesson, index|
          lesson.head.to_s.scan(/\p{Han}+/).uniq.each { |form| index[form] << lesson }
        end
      end

      def matches?(lesson, needle)
        return true if lesson.slug.include?(needle) || lesson.pattern.downcase.include?(needle)
        return true if lesson.heads.any? { |head| head.include?(needle) }
        return true if lesson.formula.values.any? { |text| text.to_s.downcase.include?(needle) }

        [lesson.en, lesson.ru].any? { |source| source["title"].to_s.downcase.include?(needle) }
      end

      def payload
        rows = DATA.value
        return @payload if defined?(@payload) && @rows.equal?(rows)

        @rows = rows
        @by_form = nil
        @payload = rows
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
                  sentence: example["sentence"],
                  segments: Array(example["segments"])
                )
              end,
              excluded: row["excluded"],
              supplementary: row["supplementary"],
              glossary: row["glossary"] || {}
            )
          end
          .freeze
      end
    end
  end
end
