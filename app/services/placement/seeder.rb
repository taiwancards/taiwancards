# frozen_string_literal: true

module Placement
  class Seeder
    FREQ_CUTOFF = {1 => 500, 2 => 1_000, 3 => 2_000, 4 => 3_500, 5 => 5_000, 6 => 7_000, 7 => 10_000}.freeze
    FACETS = %w[recognition reading].freeze
    BASE_STABILITY = 45.0
    DIFFICULTY = 5.0
    FIRST_DUE_DAY = 14
    MIN_WINDOW_DAYS = 60
    MAX_WINDOW_DAYS = 365
    UPKEEP_SHARE = 1 / 3r
    UPKEEP_PER_DAY = 5
    RESTING_FROM_DAY = 365
    RESTING_WINDOW_DAYS = 365
    BATCH = 5_000
    UNIQUE_BY = %i[lexeme_id facet user_id].freeze
    FACET_OVERRIDE = Arel.sql("lexemes.data -> 'facets'")

    def initialize(user, now: Time.current, rng: Random.new)
      @user = user
      @now = now
      @rng = rng
    end

    def call(grade)
      grade = grade.to_i
      return {seeded: 0, lexemes: 0} if grade < 1

      candidates = scope(grade).pluck(:id, :kind, FACET_OVERRIDE, :level_index)
      upkeep, resting = split(candidates, grade)
      studied = studied_pairs
      rows = rows_for(upkeep, studied, from: FIRST_DUE_DAY, window: window_days(upkeep.size)) +
        rows_for(resting, studied, from: RESTING_FROM_DAY, window: RESTING_WINDOW_DAYS)
      rows.each_slice(BATCH) { |slice| LexemeMemory.upsert_all(slice, unique_by: UNIQUE_BY) }

      {seeded: rows.size, lexemes: candidates.size}
    end

    def reseat(grade)
      untouched.delete_all
      call(grade)
    end

    private

    def untouched
      LexemeMemory
        .owned_by(@user)
        .state_review
        .where(reps: 1, lapses: 0, difficulty: DIFFICULTY)
        .where("NOT EXISTS (SELECT 1 FROM lexeme_reviews r WHERE r.lexeme_memory_id = lexeme_memories.id)")
    end

    def scope(grade)
      cutoff = FREQ_CUTOFF[grade] || FREQ_CUTOFF[FREQ_CUTOFF.keys.max]
      Lexeme
        .unrestricted
        .where(kind: %i[character word])
        .where(
          "#{Lexeme::LEVEL_INDEX_SQL} <= :grade OR (#{Lexeme::LEVEL_INDEX_SQL} IS NULL AND #{Lexeme::FREQ_RANK_SQL} <= :cutoff)",
          grade:,
          cutoff:
        )
        .order(Arel.sql("#{Lexeme::LEVEL_INDEX_SQL} DESC NULLS LAST, #{Lexeme::FREQ_RANK_SQL} DESC NULLS LAST"), :id)
    end

    def split(candidates, grade)
      own = candidates.select { |(_id, _kind, _override, level)| level == grade }
      upkeep = own.first((own.size * UPKEEP_SHARE).ceil)
      chosen = upkeep.to_set(&:first)
      [upkeep, candidates.reject { |(id)| chosen.include?(id) }]
    end

    def rows_for(candidates, studied, from:, window:)
      candidates.each_with_index.flat_map do |(lexeme_id, kind, override), index|
        (Lexemes::Facets.declared(kind, override) & FACETS).filter_map do |facet|
          next if studied.include?([lexeme_id, facet])

          {lexeme_id:, facet:, user_id: @user.id, **seed_attributes(from + (index.to_f / candidates.size * window))}
        end
      end
    end

    def studied_pairs
      LexemeMemory
        .owned_by(@user)
        .where(facet: FACETS)
        .where
        .not(state: :unseen, reps: 0)
        .pluck(:lexeme_id, :facet)
        .to_set
    end

    def window_days(total)
      return MIN_WINDOW_DAYS if total.zero?

      (total / UPKEEP_PER_DAY.to_f).ceil.clamp(MIN_WINDOW_DAYS, MAX_WINDOW_DAYS)
    end

    def seed_attributes(days)
      {
        state: :review,
        stability: BASE_STABILITY * @rng.rand(0.8..1.2),
        difficulty: DIFFICULTY,
        reps: 1,
        lapses: 0,
        step: 0,
        activated_at: @now,
        last_reviewed_at: @now,
        due_at: @now + days.days
      }
    end
  end
end
