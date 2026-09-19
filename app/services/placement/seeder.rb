# frozen_string_literal: true

module Placement
  class Seeder
    FREQ_CUTOFF = {1 => 500, 2 => 1_000, 3 => 2_000, 4 => 3_500, 5 => 5_000, 6 => 7_000, 7 => 10_000}.freeze
    FACETS = %w[recognition reading].freeze
    BASE_STABILITY = 45.0
    DIFFICULTY = 5.0
    FIRST_DUE_DAY = 14
    MIN_WINDOW_DAYS = 60
    MAX_WINDOW_DAYS = 240
    REVIEWS_PER_DAY = 40
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

      candidates = scope(grade).pluck(:id, :kind, FACET_OVERRIDE)
      rows = rows_for(candidates)
      rows.each_slice(BATCH) { |slice| LexemeMemory.upsert_all(slice, unique_by: UNIQUE_BY) }

      {seeded: rows.size, lexemes: candidates.size}
    end

    private

    def scope(grade)
      cutoff = FREQ_CUTOFF[grade] || FREQ_CUTOFF[FREQ_CUTOFF.keys.max]
      Lexeme
        .unrestricted
        .where(kind: %i[character word])
        .where(
          "#{Lexeme::LEVEL_INDEX_SQL} <= :grade OR #{Lexeme::FREQ_RANK_SQL} <= :cutoff",
          grade:,
          cutoff:
        )
        .curriculum_order
    end

    def rows_for(candidates)
      window = window_days(candidates.size)
      studied = studied_pairs

      candidates.each_with_index.flat_map do |(lexeme_id, kind, override), index|
        (Lexemes::Facets.declared(kind, override) & FACETS).filter_map do |facet|
          next if studied.include?([lexeme_id, facet])

          {lexeme_id:, facet:, user_id: @user.id, **seed_attributes(index, candidates.size, window)}
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

      (total / REVIEWS_PER_DAY.to_f).ceil.clamp(MIN_WINDOW_DAYS, MAX_WINDOW_DAYS)
    end

    def seed_attributes(index, total, window)
      offset = total.zero? ? 0 : (index.to_f / total * window)
      due = @now + (FIRST_DUE_DAY + offset).days
      {
        state: :review,
        stability: BASE_STABILITY * @rng.rand(0.8..1.2),
        difficulty: DIFFICULTY,
        reps: 1,
        lapses: 0,
        step: 0,
        activated_at: @now,
        last_reviewed_at: @now,
        due_at: due
      }
    end
  end
end
