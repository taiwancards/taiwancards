# frozen_string_literal: true

class StatsReport
  LEECH_LAPSES = 8
  REVIEW_STATES = %w[review relearning].freeze
  GRADUATING_STATES = %w[unseen learning].freeze
  MATURE_DAYS = 21.0

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
    total, recalled = language_reviews
      .where(reviewed_at: (@now - days.days)..)
      .where(state_before: LexemeMemory.states.values_at(*REVIEW_STATES))
      .pick(
        Arel.sql("COUNT(*)"),
        Arel.sql(
          LexemeReview.sanitize_sql_array(
            ["COUNT(*) FILTER (WHERE rating <> ?)", Fsrs::Scheduler::RATINGS.fetch(:again)]
          )
        )
      )
    return nil if total.to_i.zero?

    recalled.to_i.fdiv(total)
  end

  def average_answer_ms(days: 30)
    language_reviews.where(reviewed_at: (@now - days.days)..).average(:elapsed_ms)&.round
  end

  def memory_breakdown
    states = LexemeMemory.states
    unseen, learning, young, mature = language_memories.pick(
      *[
        ["state = ?", states["unseen"]],
        ["state IN (?)", states.values_at("learning", "relearning")],
        ["state = ? AND stability < ?", states["review"], MATURE_DAYS],
        ["state = ? AND stability >= ?", states["review"], MATURE_DAYS]
      ].map { |condition|
        Arel.sql(LexemeMemory.sanitize_sql_array(["COUNT(*) FILTER (WHERE #{condition.first})", *condition.drop(1)]))
      }
    )
    {unseen: unseen.to_i, learning: learning.to_i, young: young.to_i, mature: mature.to_i}
  end

  def words_known
    language_memories.state_review.distinct.count(:lexeme_id)
  end

  def facet_strength
    counts = language_memories.where.not(state: :unseen).group(:facet, :state).count
    LexemeMemory.facets.keys.filter_map do |facet|
      active = counts.sum { |(name, _), count| name == facet ? count : 0 }
      next if active.zero?

      {facet:, active:, known: counts.fetch([facet, "review"], 0)}
    end
  end

  def learned_by_week(weeks: 8)
    start = (@now - (weeks - 1).weeks).beginning_of_week
    firsts = language_reviews
      .where(state_before: LexemeMemory.states.values_at(*GRADUATING_STATES), scheduled_days: 1.0..)
      .group(:lexeme_id)
      .having("MIN(reviewed_at) >= ?", start)
      .minimum(:reviewed_at)
    counts = firsts.values.map { |at| at.in_time_zone.to_date.beginning_of_week }.tally

    (0...weeks).map { |offset| (start + offset.weeks).to_date }.map { |week| [week, counts.fetch(week, 0)] }
  end

  def forecast(days: 7)
    today = @now.to_date
    counts = language_memories
      .where
      .not(state: :unseen)
      .where(due_at: ..(@now + (days - 1).days).end_of_day)
      .group(Arel.sql(local_date_sql("due_at")))
      .count
      .each_with_object(Hash.new(0)) { |(date, count), sums| sums[[date.to_date, today].max] += count }

    (0...days).map { |offset| [today + offset, counts[today + offset]] }
  end

  def leeches
    Lexeme
      .joins(:memories)
      .all
      .where(lexeme_memories: {user_id: @user&.id, lapses: LEECH_LAPSES..})
      .distinct
  end

  private

  def local_date_sql(column = "reviewed_at")
    "DATE(#{column} AT TIME ZONE 'UTC' AT TIME ZONE #{ActiveRecord::Base.connection.quote(Time.zone.tzinfo.name)})"
  end

  def language_reviews
    LexemeReview.owned_by(@user)
  end

  def language_memories
    LexemeMemory.active.owned_by(@user)
  end
end
