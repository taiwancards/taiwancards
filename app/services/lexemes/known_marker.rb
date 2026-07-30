# frozen_string_literal: true

module Lexemes
  class KnownMarker
    FACETS = %w[recognition reading].freeze
    BASE_STABILITY = 60.0
    DIFFICULTY = 4.0
    FIRST_DUE_DAY = 21
    MIN_WINDOW_DAYS = 45
    MAX_WINDOW_DAYS = 180
    REVIEWS_PER_DAY = 40

    def initialize(user, now: Time.current, rng: Random.new)
      @user = user
      @now = now
      @rng = rng
    end

    def call(lexemes)
      lexemes = Array(lexemes)
      return {marked: 0, lexemes: 0} if lexemes.empty?

      window = window_days(lexemes.size)
      marked = 0

      lexemes.each_with_index do |lexeme, index|
        FACETS.each do |facet|
          next unless Lexemes::Facets.for(lexeme).include?(facet)

          memory = LexemeMemory.find_or_initialize_by(lexeme:, facet: LexemeMemory.facets[facet], user: @user)
          due = @now + (FIRST_DUE_DAY + offset_for(index, lexemes.size, window)).days

          if fresh?(memory)
            memory.assign_attributes(seed_attributes(due))
          elsif memory.due_at.nil? || memory.due_at < due
            memory.assign_attributes(due_at: due, stability: [memory.stability.to_f, BASE_STABILITY].max)
          else
            next
          end

          memory.save!
          marked += 1
        end
      end

      {marked:, lexemes: lexemes.size}
    end

    def keep_normal(lexemes)
      activator = Lexemes::Activator.new(now: @now)
      Array(lexemes).each { |lexeme| activator.call(lexeme) }

      {kept: Array(lexemes).size}
    end

    private

    def fresh?(memory)
      memory.new_record? || (memory.state_unseen? && memory.reps.to_i.zero?)
    end

    def window_days(total)
      (total / REVIEWS_PER_DAY.to_f).ceil.clamp(MIN_WINDOW_DAYS, MAX_WINDOW_DAYS)
    end

    def offset_for(index, total, window)
      total.zero? ? 0 : (index.to_f / total * window)
    end

    def seed_attributes(due)
      {
        state: :review,
        stability: BASE_STABILITY * @rng.rand(0.85..1.15),
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
