# frozen_string_literal: true

class StatsReport
  LEECH_LAPSES = 8
  REVIEW_STATES = %w[review relearning].freeze

  def initialize(user: nil, now: Time.current)
    @user = user
    @now = now
  end

  def reviews_by_day(days: 14)
    counts = language_reviews
      .where(reviewed_at: (@now - (days - 1).days).beginning_of_day..)
      .group(Arel.sql(local_date_sql))
      .count
      .transform_keys(&:to_date)
    (0...days)
      .map do |offset|
        date = (@now - offset.days).to_date
        [date, counts.fetch(date, 0)]
      end
      .reverse
  end

  def actual_retention(days: 30)
    scope = language_reviews
      .where(reviewed_at: (@now - days.days)..)
      .where(state_before: LexemeMemory.states.values_at(*REVIEW_STATES))
    total = scope.count
    return nil if total.zero?

    scope.where.not(rating: Fsrs::Scheduler::RATINGS.fetch(:again)).count.fdiv(total)
  end

  def average_answer_ms(days: 30)
    language_reviews.where(reviewed_at: (@now - days.days)..).average(:elapsed_ms)&.round
  end

  def memory_breakdown
    memories = language_memories
    {
      unseen: memories.state_unseen.count,
      learning: memories.where(state: %i[learning relearning]).count,
      young: memories.state_review.where(stability: ...21.0).count,
      mature: memories.state_review.where(stability: 21.0..).count
    }
  end

  def leeches
    Lexeme
      .joins(:memories)
      .all
      .where(lexeme_memories: {user_id: @user&.id, lapses: LEECH_LAPSES..})
      .distinct
  end

  def streak
    dates = language_reviews.distinct.pluck(Arel.sql(local_date_sql)).to_set
    return 0 if dates.empty?

    day = dates.include?(@now.to_date) ? @now.to_date : @now.to_date - 1
    count = 0
    while dates.include?(day)
      count += 1
      day -= 1
    end

    count
  end

  private

  def local_date_sql
    "DATE(reviewed_at AT TIME ZONE 'UTC' AT TIME ZONE #{ActiveRecord::Base.connection.quote(Time.zone.tzinfo.name)})"
  end

  def language_reviews
    LexemeReview.owned_by(@user)
  end

  def language_memories
    LexemeMemory.active.owned_by(@user)
  end
end
