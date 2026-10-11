# frozen_string_literal: true

module Reminders
  class Dose
    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def call(due) = [due, size].min

    def size = @size ||= regular? ? round(typical_day) : settings.fetch(:starter)

    def regular? = days.size >= settings.fetch(:regular_days)

    def typical_day
      sorted = days.sort
      sorted.empty? ? 0 : sorted[sorted.size / 2]
    end

    private

    def settings = Schedule.dose

    def round(cards)
      steps = settings.fetch(:steps)
      steps.min_by { |step| [(step - cards).abs, -step] }
    end

    def habit_window
      last = LexemeReview.where(user: @user, reviewed_at: ..@now).maximum(:reviewed_at) || @now
      (last - settings.fetch(:habit_days).days)..last
    end

    def days
      @days ||= LexemeReview
        .where(user: @user, reviewed_at: habit_window)
        .group(:reviewed_on)
        .distinct
        .count(:lexeme_id)
        .values
    end
  end
end
