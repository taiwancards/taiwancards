# frozen_string_literal: true

module Huayu
  class StarterTrack
    DATA = JsonData.new("huayu/starter_track.json", default: {}, watch: true)

    extend LessonData

    Localized = LessonData::Localized

    Word = Data.define(:zh, :glosses) do
      include Localized

      def gloss(locale) = pick(glosses, locale)
    end

    Phrase = Data.define(:zh, :zhuyin, :translations) do
      include Localized

      def translation(locale) = pick(translations, locale)
    end

    Lesson = Data.define(:slug, :number, :title, :symbols, :words, :capsule, :phrase) do
      include Localized

      def to_param = slug

      def title_for(locale) = pick(title, locale)

      def capsule_for(locale) = pick(capsule, locale)
    end

    class << self
      def total = lessons.size

      def symbols_through(lesson) = lessons.take_while { |entry| entry.number <= lesson.number }.flat_map(&:symbols)

      def words_before(lesson) = lessons.take_while { |entry| entry.number < lesson.number }.flat_map(&:words)

      private

      def build(raw)
        lessons = Array(raw["lessons"]).each_with_index.map { |row, index| build_lesson(row, index + 1) }.freeze
        {lessons:, by_slug: slug_index(lessons).freeze}.freeze
      end

      def build_lesson(row, number)
        phrase = row["phrase"].to_h
        Lesson.new(
          slug: row["slug"].to_s,
          number:,
          title: row["title"].to_h,
          symbols: Array(row["symbols"]).freeze,
          words: Array(row["words"]).map { |word| Word.new(zh: word["zh"].to_s, glosses: word.except("zh")) }.freeze,
          capsule: row["capsule"].to_h,
          phrase: phrase["zh"].present? ? Phrase.new(
            zh: phrase["zh"],
            zhuyin: phrase["zhuyin"].to_s,
            translations: phrase.except("zh", "zhuyin")
          ) : nil
        )
      end
    end
  end
end
