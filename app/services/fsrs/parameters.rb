# frozen_string_literal: true

module Fsrs
  DEFAULT_WEIGHTS = [
    0.212,
    1.2931,
    2.3065,
    8.2956,
    6.4133,
    0.8334,
    3.0194,
    0.001,
    1.8722,
    0.1666,
    0.796,
    1.4835,
    0.0614,
    0.2629,
    1.6483,
    0.6014,
    1.8729,
    0.5425,
    0.0912,
    0.0658,
    0.1542
  ].freeze

  Parameters = Data.define(
    :weights,
    :desired_retention,
    :learning_steps,
    :relearning_steps,
    :maximum_interval,
    :enable_fuzzing
  ) do
    def self.default(**overrides)
      new(
        **{
          weights: DEFAULT_WEIGHTS,
          desired_retention: 0.9,
          learning_steps: [1, 10],
          relearning_steps: [10],
          maximum_interval: 36_500,
          enable_fuzzing: true
        }.merge(overrides)
      )
    end

    def decay = -weights[20]

    def factor = (0.9 ** (1 / decay)) - 1
  end
end
