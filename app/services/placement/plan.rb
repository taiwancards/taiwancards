# frozen_string_literal: true

module Placement
  class Plan
    WEIGHTS = {
      "lexis" => 0.22,
      "vocab_size" => 0.16,
      "sentences" => 0.16,
      "grammar" => 0.14,
      "characters" => 0.14,
      "listening" => 0.10,
      "script" => 0.04,
      "tones" => 0.02,
      "syllables" => 0.02
    }.freeze

    DIAGNOSTIC = %w[taiwan traditional writing].freeze

    CAP = {
      "listening" => 4,
      "tones" => 3,
      "syllables" => 2,
      "script" => 2,
      "characters" => 4,
      "lexis" => 5,
      "vocab_size" => 4,
      "grammar" => 3,
      "sentences" => 3,
      "taiwan" => 2,
      "traditional" => 2,
      "writing" => 1
    }.freeze

    DEAD_END = 3
    SPLIT_GRADES = 2

    Step = Data.define(:finished, :axis, :grade, :outcome)

    Outcome = Data.define(:grade, :position, :error, :tolerance, :axes, :split, :diagnostics) do
      def split? = split.present?
    end

    def initialize(intake, asked)
      @intake = intake
      @asked = Array(asked).map { |row| row.to_h.stringify_keys }
    end

    def next_step(skip: [])
      available = open_axes - Array(skip)
      return finish if budget_spent? || available.empty?

      axis = available.max_by { |name| [information(name), -asked_for(name).length] }
      Step.new(finished: false, axis:, grade: grade_for(axis), outcome: nil)
    end

    def outcome
      estimates = @intake.axes.to_h { |axis| [axis, estimate(axis)] }.compact
      overall = combine(estimates.slice(*WEIGHTS.keys))

      Outcome.new(
        grade: overall.grade,
        position: overall.position,
        error: overall.error,
        tolerance: overall.tolerance,
        axes: estimates.transform_values(&:grade),
        split: split_for(estimates),
        diagnostics: diagnostics
      )
    end

    private

    def finish = Step.new(finished: true, axis: nil, grade: nil, outcome:)

    def budget_spent? = @asked.length >= @intake.budget

    def open_axes = @intake.axes.reject { |axis| capped?(axis) || dead_end?(axis) }

    def capped?(axis) = asked_for(axis).length >= cap(axis)

    def cap(axis) = @intake.budget <= Intake::SHORT_BUDGET ? 1 : CAP.fetch(axis, 2)

    def dead_end?(axis)
      rows = asked_for(axis)
      rows.length >= DEAD_END && rows.none? { |row| row["correct"] }
    end

    def information(axis)
      current = estimate(axis)
      WEIGHTS.fetch(axis, 0.05) * (current ? current.error : Ability::PRIOR_SIGMA)
    end

    def asked_for(axis) = @asked.select { |row| row["axis"] == axis }

    def grade_for(axis)
      rows = asked_for(axis)
      return @intake.prior if rows.empty?

      estimate(axis).grade
    end

    def estimate(axis)
      rows = asked_for(axis)
      return nil if rows.empty?

      Ability.call(rows, prior: @intake.prior)
    end

    def combine(scored)
      return Ability.call([], prior: @intake.prior) if scored.empty?

      total = scored.sum { |axis, _| WEIGHTS.fetch(axis) }
      theta = scored.sum { |axis, value| WEIGHTS.fetch(axis) * value.theta } / total
      error = Math.sqrt(scored.sum { |axis, value| (WEIGHTS.fetch(axis) * value.error) ** 2 }) / total
      Ability::Estimate.new(theta:, error:, **Ability.band(theta))
    end

    def split_for(estimates)
      heard = estimates["listening"]
      read = estimates["characters"] || estimates["lexis"]
      return nil if heard.nil? || read.nil? || (heard.grade - read.grade).abs < SPLIT_GRADES

      {"listening" => heard.grade, "reading" => read.grade}
    end

    def diagnostics
      DIAGNOSTIC
        .filter_map { |axis|
          rows = asked_for(axis)
          [axis, rows.count { |row| row["correct"] }.fdiv(rows.length)] if rows.any?
        }
        .to_h
    end
  end
end
