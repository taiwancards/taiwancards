# frozen_string_literal: true

module Huayu
  class LevelLadder
    STEPS = %w[at0 third half twothirds].freeze
    FRACTIONS = {"third" => 1.0 / 3, "half" => 0.5, "twothirds" => 2.0 / 3}.freeze
    PATH = "huayu/level_ladder.json"
    MAX_LEVEL = 7
    BUCKETS = 101

    extend MemoizedInstance

    class << self
      delegate :tolerance, :table, to: :instance
    end

    def initialize(table: nil)
      @table = table || load_table
    end

    def tolerance(scale, level, step)
      return 0 if step == "at0"

      @table.dig(scale.to_s, level.to_i.to_s, step).to_i
    end

    attr_reader :table

    private

    def load_table
      path = AppData.path(PATH)
      return JSON.parse(path.read) if path.exist?

      fallback
    end

    def fallback
      LevelThresholds::SCALES.to_h do |scale|
        [scale, (1..MAX_LEVEL).to_h { |level| [level.to_s, FRACTIONS.keys.to_h { |step| [step, 0] }] }]
      end
    end
  end
end
