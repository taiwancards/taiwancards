# frozen_string_literal: true

module Placement
  class Ability
    MIN_GRADE = 1
    MAX_GRADE = 7
    STEPS = 96
    LOW = -3.0
    HIGH = 3.0
    PRIOR_SIGMA = 1.5
    GUESS = 0.25

    Estimate = Data.define(:theta, :error, :grade, :position) do
      def confident? = error < 0.9
    end

    def self.call(...) = new.call(...)

    def call(responses, prior: 2)
      grid = posterior(responses, prior)
      theta = grid.sum { |point, weight| point * weight }
      variance = grid.sum { |point, weight| ((point - theta) ** 2) * weight }

      Estimate.new(theta:, error: Math.sqrt(variance), **self.class.band(theta))
    end

    def self.difficulty_of(grade) = LOW + ((grade.to_f.clamp(MIN_GRADE, MAX_GRADE) - MIN_GRADE) * span)

    def self.span = (HIGH - LOW) / (MAX_GRADE - MIN_GRADE)

    def self.band(theta)
      raw = MIN_GRADE + ((theta - LOW) / span)
      clamped = raw.clamp(MIN_GRADE, MAX_GRADE)
      {grade: clamped.floor, position: (clamped - clamped.floor).clamp(0.0, 0.999)}
    end

    private

    def posterior(responses, prior)
      centre = self.class.difficulty_of(prior)
      weights = points.to_h { |point| [point, Math.exp(-((point - centre) ** 2) / (2 * PRIOR_SIGMA ** 2))] }

      Array(responses).each do |response|
        difficulty = response[:difficulty] || response["difficulty"]
        correct = response[:correct] || response["correct"]
        next if difficulty.nil?

        weights.each_key do |point|
          probability = success(point, difficulty.to_f)
          weights[point] *= correct ? probability : 1.0 - probability
        end
      end

      total = weights.values.sum
      return points.to_h { |point| [point, 1.0 / STEPS] } if total <= 0

      weights.transform_values { |weight| weight / total }
    end

    def success(theta, difficulty)
      GUESS + ((1.0 - GUESS) / (1.0 + Math.exp(difficulty - theta)))
    end

    def points
      @points ||= Array.new(STEPS) { |index| LOW + ((HIGH - LOW) * index / (STEPS - 1.0)) }
    end
  end
end
