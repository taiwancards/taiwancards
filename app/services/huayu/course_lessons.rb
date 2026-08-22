# frozen_string_literal: true

module Huayu
  class CourseLessons
    DATA = JsonData.new("huayu/course_lessons.json", default: {}, watch: true)

    extend LessonData

    REGISTERS = %w[standard spoken written].freeze

    Localised = LessonData::Localised

    Line = Data.define(:who, :zh, :en, :ru, :zhuyin, :pinyin) do
      include Localised

      def translation(locale) = locale.to_s == "ru" ? ru : en

      def syllables = zhuyin.to_s.split(/[[:space:]]+/).reject(&:empty?)
    end

    Word = Data.define(:zh, :zhuyin, :pinyin, :pos, :en, :ru, :register, :note) do
      include Localised

      def gloss(locale) = locale.to_s == "ru" ? ru : en

      def note_for(locale) = pick(note, locale)

      def marked? = REGISTERS.include?(register) && register != "standard"
    end

    GrammarRef = Data.define(:slug, :note) do
      include Localised

      def lesson = GrammarLessons.find(slug)

      def note_for(locale) = pick(note, locale)
    end

    Usage = Data.define(:street, :standard, :en, :ru) do
      include Localised

      def body(locale) = locale.to_s == "ru" ? ru : en
    end

    Exercise = Data.define(:kind, :zh, :gloss, :options, :answer, :chunks, :order, :pairs) do
      include Localised

      def prompt(locale) = pick(gloss, locale)

      def option_text(option, locale)
        option.is_a?(Hash) ? pick(option, locale) : option
      end

      def payload(locale)
        {
          kind: kind,
          zh: zh,
          prompt: prompt(locale),
          options: Array(options).map { |option| option_text(option, locale) },
          answer: answer,
          chunks: Array(chunks),
          order: Array(order),
          pairs: Array(pairs).map { |pair| {zh: pair["zh"], gloss: pick(pair, locale)} }
        }.compact_blank
      end
    end

    Lesson = Data.define(
      :slug,
      :number,
      :stage,
      :zh_title,
      :title,
      :goal,
      :kind,
      :lines,
      :vocabulary,
      :grammar,
      :culture,
      :usage,
      :exercises
    ) do
      include Localised

      def to_param = slug

      def title_for(locale) = pick(title, locale)

      def goal_for(locale) = pick(goal, locale)

      def culture_for(locale) = pick(culture, locale)

      def dialogue? = kind == "dialogue"

      def body = lines.map(&:zh).join("\n")

      def words = vocabulary.map(&:zh)

      def exercise_payload(locale) = exercises.map { |exercise| exercise.payload(locale) }
    end

    Stage = Data.define(:slug, :band, :order, :zh, :en, :ru, :exam) do
      include Localised

      def to_param = slug

      def title(locale) = pick(locale.to_s == "ru" ? ru : en, "title") || slug

      def body(locale)
        source = locale.to_s == "ru" ? ru : en
        source["body"]
      end
    end

    class << self
      def stages = payload[:stages]

      def by_stage = payload[:by_stage]

      def stage(slug) = stages.find { |entry| entry.slug == slug.to_s }

      private

      def build(rows)
        lessons = build_lessons(rows)
        {
          stages: build_stages(rows),
          lessons: lessons,
          by_slug: slug_index(lessons).freeze,
          by_stage: lessons.group_by(&:stage).freeze
        }.freeze
      end

      def build_stages(rows)
        Array(rows["stages"])
          .map do |row|
            Stage.new(
              slug: row["slug"],
              band: row["band"],
              order: row["order"].to_i,
              zh: row["zh"],
              en: row["en"] || {},
              ru: row["ru"] || {},
              exam: build_exercises(row, "exam")
            )
          end
          .sort_by(&:order)
          .freeze
      end

      def build_lessons(rows)
        Array(rows["lessons"]).map { |row| build_lesson(row) }.sort_by(&:number).freeze
      end

      def build_lesson(row)
        Lesson.new(
          slug: row["slug"],
          number: row["number"].to_i,
          stage: row["stage"],
          zh_title: row["zh_title"],
          title: row["title"] || {},
          goal: row["goal"] || {},
          kind: row.dig("text", "kind") || "passage",
          lines: build_lines(row),
          vocabulary: build_vocabulary(row),
          grammar: build_grammar(row),
          culture: row["culture"] || {},
          usage: build_usage(row),
          exercises: build_exercises(row)
        )
      end

      def build_lines(row)
        Array(row.dig("text", "lines")).map do |line|
          Line.new(
            who: line["who"],
            zh: line["zh"],
            en: line["en"],
            ru: line["ru"],
            zhuyin: line["zhuyin"],
            pinyin: line["pinyin"]
          )
        end
      end

      def build_vocabulary(row)
        Array(row["vocabulary"]).map do |word|
          Word.new(
            zh: word["zh"],
            zhuyin: word["zhuyin"],
            pinyin: word["pinyin"],
            pos: word["pos"],
            en: word["en"],
            ru: word["ru"],
            register: word["register"] || "standard",
            note: word["note"]
          )
        end
      end

      def build_grammar(row)
        Array(row["grammar"]).map { |ref| GrammarRef.new(slug: ref["slug"], note: ref["note"] || {}) }
      end

      def build_usage(row)
        Array(row["usage"]).map do |entry|
          Usage.new(street: entry["street"], standard: entry["standard"], en: entry["en"], ru: entry["ru"])
        end
      end

      def build_exercises(row, key = "exercises")
        Array(row[key]).map do |exercise|
          Exercise.new(
            kind: exercise["kind"],
            zh: exercise["zh"],
            gloss: exercise["gloss"] || {},
            options: exercise["options"] || [],
            answer: exercise["answer"],
            chunks: exercise["chunks"] || [],
            order: exercise["order"] || [],
            pairs: exercise["pairs"] || []
          )
        end
      end
    end
  end
end
