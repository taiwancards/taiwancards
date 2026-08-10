# frozen_string_literal: true

module Huayu
  class LevelThresholds
    SCALES = %w[tbcl tocfl].freeze
    STEPS = LevelLadder::STEPS
    NEVER = 99
    MAX_LEVEL = LevelLadder::MAX_LEVEL

    COLUMNS = SCALES.to_h { |scale| [scale, STEPS.to_h { |step| [step, :"#{scale}_#{step}"] }] }.freeze

    extend MemoizedInstance

    class << self
      def columns_for(scale) = COLUMNS.fetch(scale).values

      delegate :for_tokens, :for_level, to: :instance
    end

    def initialize(ladder: nil)
      @ladder = ladder || LevelLadder.instance
      @levels = SCALES.to_h { |scale| [scale, load_levels(scale)] }
    end

    def for_level(scale, level)
      value = level.nil? ? NEVER : level
      STEPS.to_h { |step| [COLUMNS.fetch(scale).fetch(step), value] }
    end

    def for_tokens(scale, tokens)
      total = tokens.length
      return STEPS.to_h { |step| [COLUMNS.fetch(scale).fetch(step), NEVER] } if total.zero?

      table = @levels.fetch(scale)
      counts = Array.new(MAX_LEVEL + 2, 0)
      tokens.each { |token| counts[table[token] || (MAX_LEVEL + 1)] += 1 }

      shares = Array.new(MAX_LEVEL + 1, NEVER)
      above = 0
      (MAX_LEVEL + 1).downto(1) do |level|
        above += counts[level]
        shares[level - 1] = above * 100.0 / total
      end

      STEPS.to_h { |step| [COLUMNS.fetch(scale).fetch(step), threshold(scale, shares, step)] }
    end

    private

    def threshold(scale, shares, step)
      found = NEVER

      MAX_LEVEL.downto(1) do |level|
        allowed = @ladder.tolerance(scale, level, step)
        break if shares[level] > allowed

        found = level
      end

      found
    end

    def load_levels(scale)
      column = scale == "tbcl" ? "tbcl_grade" : "tocfl_level"
      order = SentenceProfile::TOCFL_LEVELS.each_with_index.to_h { |name, index| [name, index + 1] }

      Lexeme
        .where(kind: %i[word collocation character])
        .where("data ? :key", key: column)
        .pluck(:text, Arel.sql("data->>'#{column}'"))
        .filter_map { |text, value|
          level = scale == "tbcl" ? value.to_i : order[value]
          [text, level] if level&.positive?
        }
        .to_h
    end
  end
end
