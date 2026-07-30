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

    def initialize(user, now: Time.current, rng: Random.new)
      @user = user
      @now = now
      @rng = rng
    end

    def call(grade)
      grade = grade.to_i
      return {seeded: 0, lexemes: 0} if grade < 1

      lexemes = scope(grade).to_a
      window = window_days(lexemes.size)
      seeded = 0

      lexemes.each_with_index do |lexeme, index|
        FACETS.each do |facet|
          next unless applicable?(lexeme, facet)

          memory = LexemeMemory.find_or_initialize_by(lexeme:, facet: LexemeMemory.facets[facet], user: @user)
          next unless seedable?(memory)

          memory.assign_attributes(seed_attributes(index, lexemes.size, window))
          memory.save!
          seeded += 1
        end
      end

      {seeded:, lexemes: lexemes.size}
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

    def applicable?(lexeme, facet)
      Lexemes::Facets.for(lexeme).include?(facet)
    end

    def seedable?(memory)
      memory.new_record? || (memory.state_unseen? && memory.reps.to_i.zero?)
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
