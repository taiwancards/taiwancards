# frozen_string_literal: true

module Huayu
  class WordPairs
    extend LessonData

    DATA = JsonData.new("huayu/word_pairs.json", default: {"pairs" => []}, watch: true)
    LEVELS = %w[A1 A2 B1].freeze

    Word = Data.define(:zh, :pinyin, :zhuyin, :glosses) do
      include LessonData::Localized

      def gloss(locale) = pick(glosses, locale)
    end

    Example = Data.define(:zh, :translations) do
      include LessonData::Localized

      def translation(locale) = pick(translations, locale)
    end

    Use = Data.define(:word, :notes, :examples) do
      include LessonData::Localized

      def note(locale) = pick(notes, locale)
    end

    Mistake = Data.define(:wrong, :right, :notes) do
      include LessonData::Localized

      def note(locale) = pick(notes, locale)
    end

    Pair = Data.define(:slug, :level, :words, :gists, :rules, :uses, :mistakes, :exercises, :reasons) do
      include LessonData::Localized

      def to_param = slug

      def title = words.map(&:zh).join("、")

      def gist(locale) = pick(gists, locale)

      def rule(locale) = pick(rules, locale)

      def texts = words.map(&:zh)

      def explain(exercise, locale)
        reason = reasons[exercise]
        return nil if reason.nil?

        CourseExplainer::Explanation.new(
          kind: "pair",
          zh: exercise.zh.sub(BLANK, exercise.right_option.to_s),
          reading: nil,
          body: pick(reason, locale),
          detail: nil,
          grammar: nil
        )
      end
    end

    BLANK = "＿＿"

    class << self
      def levels = payload[:levels]

      def for_word(text) = payload[:by_word].fetch(text.to_s, [])

      private

      def build(raw)
        pairs = Array(raw["pairs"]).map { |row| pair_from(row) }
        {
          lessons: pairs.freeze,
          by_slug: slug_index(pairs).freeze,
          levels: pairs.group_by(&:level).slice(*LEVELS).freeze,
          by_word: pairs
            .each_with_object(Hash.new { |hash, key| hash[key] = [] }) { |pair, index|
              pair.texts.each { |text| index[text] << pair }
            }
            .tap { |index| index.default_proc = nil }
            .freeze
        }
      end

      def pair_from(row)
        exercises = Array(row["drills"]).map { |drill| [exercise_from(drill), drill["why"]] }
        Pair.new(
          slug: row["slug"],
          level: row["level"],
          words: Array(row["words"]).map { |word| word_from(word) }.freeze,
          gists: Hash(row["gist"]).freeze,
          rules: Hash(row["rule"]).freeze,
          uses: Array(row["uses"]).map { |use| use_from(use) }.freeze,
          mistakes: Array(row["mistakes"]).map { |mistake| mistake_from(mistake) }.freeze,
          exercises: exercises.map(&:first).freeze,
          reasons: exercises.to_h.freeze
        )
      end

      def word_from(row)
        Word.new(
          zh: row["zh"],
          pinyin: row["pinyin"],
          zhuyin: Zhuyin.from_pinyin(row["pinyin"]),
          glosses: row.slice("en", "ru").freeze
        )
      end

      def use_from(row)
        Use.new(
          word: row["word"],
          notes: row.slice("en", "ru").freeze,
          examples: Array(row["examples"])
            .map { |example| Example.new(zh: example["zh"], translations: example.slice("en", "ru").freeze) }
            .freeze
        )
      end

      def mistake_from(row)
        Mistake.new(wrong: row["wrong"], right: row["right"], notes: row.slice("en", "ru").freeze)
      end

      def exercise_from(row)
        CourseLessons::Exercise.new(
          kind: "cloze",
          zh: row["zh"],
          gloss: row.slice("en", "ru").freeze,
          options: Array(row["options"]).freeze,
          answer: row["answer"].to_i,
          chunks: [],
          order: [],
          pairs: []
        )
      end
    end
  end
end
