# frozen_string_literal: true

module Lexemes
  class ReviewProcessor
    def initialize(scheduler: Fsrs::Scheduler.new(parameters: Setting.instance.fsrs_parameters))
      @scheduler = scheduler
    end

    def call(memory, rating:, elapsed_ms: nil, session_id: nil, now: Time.current)
      result = @scheduler.review(
        state: memory.state,
        step: memory.step,
        stability: memory.stability,
        difficulty: memory.difficulty,
        last_reviewed_at: memory.last_reviewed_at,
        rating:,
        now:
      )

      memory.transaction do
        review = memory.lexeme_reviews.create!(
          lexeme: memory.lexeme,
          user: memory.user,
          reviewed_at: now,
          rating: Fsrs::Scheduler::RATINGS.fetch(rating.to_sym),
          facet: LexemeMemory.facets[memory.facet],
          elapsed_ms:,
          session_id:,
          state_before: LexemeMemory.states[memory.state],
          elapsed_days: memory.last_reviewed_at ? (now - memory.last_reviewed_at) / 86_400.0 : nil,
          scheduled_days: result.interval_days,
          stability_before: memory.stability,
          stability_after: result.stability,
          difficulty_before: memory.difficulty,
          difficulty_after: result.difficulty,
          due_after: result.due_at
        )

        memory.update!(
          state: result.state,
          step: result.step,
          stability: result.stability,
          difficulty: result.difficulty,
          due_at: result.due_at,
          last_reviewed_at: now,
          activated_at: memory.activated_at || now,
          reps: memory.reps + 1,
          lapses: memory.lapses + (rating.to_sym == :again && memory.state_review? ? 1 : 0)
        )

        review
      end
    end
  end
end
