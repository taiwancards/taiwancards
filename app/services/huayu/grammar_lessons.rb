# frozen_string_literal: true

module Huayu
  class GrammarLessons
    extend LessonData

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
      def all = lessons

      def taught = payload[:taught]

      def levels = payload[:levels]

      def find(param)
        value = param.to_s
        super || lessons.find { |lesson| lesson.heads.include?(value) || lesson.pattern == value }
      end

      def neighbours(lesson) = super(lesson, taught)

      def search(query, limit: 6)
        needle = query.to_s.strip.downcase
        return [] if needle.empty?

        lessons.select { |lesson| matches?(lesson, needle) }.first(limit)
      end

      def for_form(text)
        form = text.to_s
        return [] if form.empty?

        payload[:by_form].fetch(form, [])
      end

      private

      def form_index(taught)
        taught.each_with_object(Hash.new { |memo, key| memo[key] = [] }) do |lesson, index|
          lesson.head.to_s.scan(/\p{Han}+/).uniq.each { |form| index[form] << lesson }
        end
      end

      def matches?(lesson, needle)
        return true if lesson.slug.include?(needle) || lesson.pattern.downcase.include?(needle)
        return true if lesson.heads.any? { |head| head.include?(needle) }
        return true if lesson.formula.values.any? { |text| text.to_s.downcase.include?(needle) }

        [lesson.en, lesson.ru].any? { |source| source["title"].to_s.downcase.include?(needle) }
      end

      def build(rows)
        lessons = rows
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
        taught = lessons.reject(&:excluded?).freeze
        {
          lessons: lessons,
          taught: taught,
          levels: taught.group_by(&:level).freeze,
          by_slug: slug_index(lessons).merge(lessons.index_by { |lesson| lesson.id.to_s }).freeze,
          by_form: form_index(taught).freeze
        }
      end
    end
  end
end
