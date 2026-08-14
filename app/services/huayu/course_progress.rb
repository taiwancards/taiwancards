# frozen_string_literal: true

module Huayu
  class CourseProgress
    BANDS = {
      "novice1" => "TOCFL Novice 1",
      "novice2" => "TOCFL Novice 2",
      "a1" => "TOCFL Band A · A1",
      "a2" => "TOCFL Band A · A2",
      "b1" => "TOCFL Band B · B1"
    }.freeze

    GRAMMAR_LEVELS = {"novice1" => 1, "novice2" => 2, "a1" => 3, "a2" => 4, "b1" => 5}.freeze

    WORDS = ProcessCache.new(ttl: 600, limit: BANDS.size)

    Slice = Data.define(
      :stage,
      :lessons,
      :done,
      :words_met,
      :words_total,
      :grammar_met,
      :grammar_total,
      :exercises_score,
      :exercises_total,
      :last_finished_at
    ) do
      def percent = share(done, lessons)

      def words_percent = share(words_met, words_total)

      def grammar_percent = share(grammar_met, grammar_total)

      def lesson_share = lessons.zero? ? 0.0 : (100.0 / lessons)

      def finished? = lessons.positive? && done == lessons

      def started? = done.positive?

      private

      def share(part, whole)
        return 0 if whole.to_i.zero?

        ((part.to_f / whole) * 100).round
      end
    end

    def self.band_words(stage)
      name = BANDS[stage]
      return Set.new if name.nil?

      WORDS.fetch(stage) do
        collection = Collection.find_by(name: name)
        collection ? collection.lexemes.pluck(:text).to_set : Set.new
      end
    end

    def self.forget_words! = WORDS.clear

    def initialize(user)
      @user = user
    end

    def slices
      @slices ||= CourseLessons.stages.map { |stage| slice(stage) }
    end

    def slice_for(stage_slug)
      slices.find { |slice| slice.stage.slug == stage_slug }
    end

    def overall
      done = slices.sum(&:done)
      lessons = slices.sum(&:lessons)
      lessons.zero? ? 0 : ((done.to_f / lessons) * 100).round
    end

    def completions
      @completions ||= CourseCompletion.owned_by(@user).index_by(&:slug)
    end

    def pace
      finished = completions.values.select(&:completed_at)
      return nil if finished.size < 2

      first = finished.map(&:completed_at).min
      last = finished.map(&:completed_at).max
      days = ((last - first) / 1.day).round.clamp(1, 3650)
      Pace.new(lessons: finished.size, days: days, first: first, last: last)
    end

    Pace = Data.define(:lessons, :days, :first, :last) do
      def per_week = ((lessons.to_f / days) * 7).round(1)

      def per_day = lessons.to_f / days

      def finish_by(remaining)
        return nil if remaining.zero? || per_day <= 0

        Date.current + (remaining / per_day).ceil
      end
    end

    private

    def slice(stage)
      lessons = CourseLessons.by_stage[stage.slug].to_a
      finished = lessons.select { |lesson| completions.key?(lesson.slug) }
      band = self.class.band_words(stage.slug)
      level = GRAMMAR_LEVELS[stage.slug]

      Slice.new(
        stage: stage,
        lessons: lessons.size,
        done: finished.size,
        words_met: finished.flat_map(&:words).uniq.count { |word| band.include?(word) },
        words_total: band.size,
        grammar_met: finished.flat_map { |lesson| lesson.grammar.map(&:slug) }.uniq.size,
        grammar_total: GrammarLessons.taught.count { |lesson| lesson.level == level },
        exercises_score: finished.sum { |lesson| completions[lesson.slug].score.to_i },
        exercises_total: finished.sum { |lesson| completions[lesson.slug].total.to_i },
        last_finished_at: finished.filter_map { |lesson| completions[lesson.slug].completed_at }.max
      )
    end
  end
end
