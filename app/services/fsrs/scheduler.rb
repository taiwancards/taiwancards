# frozen_string_literal: true

module Fsrs
  class Scheduler
    STABILITY_MIN = 0.001
    MIN_DIFFICULTY = 1.0
    MAX_DIFFICULTY = 10.0
    RATINGS = {again: 1, hard: 2, good: 3, easy: 4}.freeze
    FUZZ_RANGES = [
      {start: 2.5, finish: 7.0, factor: 0.15},
      {start: 7.0, finish: 20.0, factor: 0.1},
      {start: 20.0, finish: Float::INFINITY, factor: 0.05}
    ].freeze

    Result = Data.define(:state, :step, :stability, :difficulty, :due_at, :interval_days)

    def initialize(parameters: Parameters.default, rng: Random.new)
      @parameters = parameters
      @w = parameters.weights
      @decay = parameters.decay
      @factor = parameters.factor
      @retention_span = (parameters.desired_retention ** (1 / @decay)) - 1
      @recall_scale = Math.exp(@w[8])
      @forget_divisor = Math.exp(@w[17] * @w[18])
      @rng = rng
    end

    def review(state:, step:, stability:, difficulty:, last_reviewed_at:, rating:, now:)
      grade = RATINGS.fetch(rating.to_sym)
      state = state.to_sym
      state = :learning if state == :unseen
      days_since = last_reviewed_at ? ((now - last_reviewed_at) / 86_400).floor : nil
      same_day = !days_since.nil? && days_since < 1

      stability, difficulty = next_memory(state, stability, difficulty, days_since, same_day, grade)
      next_state, next_step, interval_seconds = transition(state, step, stability, grade)

      if @parameters.enable_fuzzing && next_state == :review
        interval_seconds = fuzz(interval_seconds / 86_400) * 86_400
      end

      Result.new(
        state: next_state,
        step: next_step,
        stability:,
        difficulty:,
        due_at: now + interval_seconds,
        interval_days: interval_seconds / 86_400.0
      )
    end

    def retrievability(elapsed_days, stability)
      return 0.0 if stability.nil?

      ((1 + @factor * [elapsed_days, 0].max / stability) ** @decay)
    end

    private

    def next_memory(state, stability, difficulty, days_since, same_day, grade)
      if stability.nil? || difficulty.nil?
        [initial_stability(grade), initial_difficulty(grade, clamp: true)]
      elsif same_day
        [short_term_stability(stability, grade), next_difficulty(difficulty, grade)]
      else
        r = retrievability(days_since, stability)
        [next_stability(difficulty, stability, r, grade), next_difficulty(difficulty, grade)]
      end
    end

    def transition(state, step, stability, grade)
      case state
      when :learning
        step_transition(@parameters.learning_steps, :learning, step, stability, grade)
      when :relearning
        step_transition(@parameters.relearning_steps, :relearning, step, stability, grade)
      when :review
        review_transition(stability, grade)
      end
    end

    def step_transition(steps, state, step, stability, grade)
      if steps.empty? || (step >= steps.length && grade >= RATINGS[:hard])
        return [:review, 0, review_interval_seconds(stability)]
      end

      case grade
      when RATINGS[:again]
        [state, 0, steps[0] * 60.0]
      when RATINGS[:hard]
        seconds = if step.zero? && steps.length == 1
          steps[0] * 60.0 * 1.5
        elsif step.zero? && steps.length >= 2
          (steps[0] + steps[1]) * 60.0 / 2.0
        else
          steps[step] * 60.0
        end

        [state, step, seconds]
      when RATINGS[:good]
        if step + 1 == steps.length
          [:review, 0, review_interval_seconds(stability)]
        else
          [state, step + 1, steps[step + 1] * 60.0]
        end

      when RATINGS[:easy]
        [:review, 0, review_interval_seconds(stability)]
      end
    end

    def review_transition(stability, grade)
      if grade == RATINGS[:again] && @parameters.relearning_steps.any?
        [:relearning, 0, @parameters.relearning_steps[0] * 60.0]
      else
        [:review, 0, review_interval_seconds(stability)]
      end
    end

    def review_interval_seconds(stability)
      interval = (stability / @factor) * @retention_span
      interval = interval.round(half: :even)
      interval = interval.clamp(1, @parameters.maximum_interval)
      interval * 86_400.0
    end

    def initial_stability(grade)
      [@w[grade - 1], STABILITY_MIN].max
    end

    def initial_difficulty(grade, clamp:)
      difficulty = @w[4] - Math.exp(@w[5] * (grade - 1)) + 1
      clamp ? difficulty.clamp(MIN_DIFFICULTY, MAX_DIFFICULTY) : difficulty
    end

    def next_difficulty(difficulty, grade)
      delta = -(@w[6] * (grade - 3))
      damped = difficulty + ((10.0 - difficulty) * delta / 9.0)
      reverted = (@w[7] * initial_difficulty(RATINGS[:easy], clamp: false)) + ((1 - @w[7]) * damped)
      reverted.clamp(MIN_DIFFICULTY, MAX_DIFFICULTY)
    end

    def next_stability(difficulty, stability, retrievability, grade)
      value = if grade == RATINGS[:again]
        next_forget_stability(difficulty, stability, retrievability)
      else
        next_recall_stability(difficulty, stability, retrievability, grade)
      end

      [value, STABILITY_MIN].max
    end

    def next_recall_stability(difficulty, stability, retrievability, grade)
      hard_penalty = grade == RATINGS[:hard] ? @w[15] : 1
      easy_bonus = grade == RATINGS[:easy] ? @w[16] : 1

      stability *
        (1 +
          @recall_scale *
          (11 - difficulty) *
          (stability ** -@w[9]) *
          (Math.exp((1 - retrievability) * @w[10]) - 1) *
          hard_penalty *
          easy_bonus)
    end

    def next_forget_stability(difficulty, stability, retrievability)
      long_term = @w[11] *
        (difficulty ** -@w[12]) *
        (((stability + 1) ** @w[13]) - 1) *
        Math.exp((1 - retrievability) * @w[14])
      short_term = stability / @forget_divisor
      [long_term, short_term].min
    end

    def short_term_stability(stability, grade)
      increase = Math.exp(@w[17] * (grade - 3 + @w[18])) * (stability ** -@w[19])
      increase = [increase, 1.0].max if grade >= RATINGS[:good]
      [stability * increase, STABILITY_MIN].max
    end

    def fuzz(interval_days)
      return interval_days.round if interval_days < 2.5

      delta = 1.0
      FUZZ_RANGES.each do |range|
        delta += range[:factor] * [[interval_days.to_f, range[:finish]].min - range[:start], 0.0].max
      end

      min_ivl = [2, (interval_days - delta).round(half: :even)].max
      max_ivl = [(interval_days + delta).round(half: :even), @parameters.maximum_interval].min
      min_ivl = [min_ivl, max_ivl].min
      fuzzed = (@rng.rand * (max_ivl - min_ivl + 1)) + min_ivl
      [fuzzed.round(half: :even), @parameters.maximum_interval].min
    end
  end
end
