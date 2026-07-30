# frozen_string_literal: true

module Huayu
  class LadderCalibrator
    MAX_LEVEL = LevelLadder::MAX_LEVEL
    BUCKETS = LevelLadder::BUCKETS

    MIN_SENTENCES = 10_000

    def initialize(io: $stdout)
      @io = io
    end

    def call
      available = Lexeme.where(kind: :sentence).count
      if available < MIN_SENTENCES
        @io.puts("  corpus too small (#{available} sentences), keeping the stored ladder")
        return LevelLadder.instance.table
      end

      levels = LevelThresholds::SCALES.to_h { |scale| [scale, vocabulary(scale)] }
      histograms = collect(levels)
      ladder = LevelThresholds::SCALES.to_h { |scale| [scale, calibrate(histograms.fetch(scale))] }

      path = AppData.path(LevelLadder::PATH)
      path.dirname.mkpath
      path.write(JSON.pretty_generate(ladder))
      LevelLadder.reset!

      report(ladder)
      ladder
    end

    private

    def vocabulary(scale)
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

    def collect(levels)
      rows = Lexeme.where(kind: :sentence).pluck(:data)

      shares = ParallelMap.call(rows) do |data|
        units = data["segments"]
        next nil unless units.is_a?(Array) && units.any?

        LevelThresholds::SCALES.to_h { |scale| [scale, share_profile(units, levels.fetch(scale))] }
      end

      grand = LevelThresholds::SCALES.to_h do |scale|
        [scale, Array.new(MAX_LEVEL + 1) { Array.new(BUCKETS, 0) }]
      end

      shares.each do |row|
        next if row.nil?

        LevelThresholds::SCALES.each do |scale|
          row.fetch(scale).each_with_index do |share, level|
            grand[scale][level][[share, BUCKETS - 1].min] += 1 if level.positive?
          end
        end
      end

      grand
    end

    def share_profile(units, table)
      counts = Array.new(MAX_LEVEL + 2, 0)
      units.each { |unit| counts[table[unit] || (MAX_LEVEL + 1)] += 1 }

      total = units.length
      above = 0
      profile = Array.new(MAX_LEVEL + 1, 0)
      (MAX_LEVEL + 1).downto(1) do |level|
        above += counts[level]
        profile[level - 1] = (above * 100.0 / total).ceil
      end

      profile
    end

    def calibrate(histogram)
      cumulative = (0..MAX_LEVEL).map do |level|
        next nil if level.zero?

        running = 0
        histogram[level].map { |value| running += value }
      end

      (1..MAX_LEVEL).to_h do |level|
        start = cumulative[level][0]
        ceiling = level < MAX_LEVEL ? cumulative[level + 1][0] : cumulative[level][BUCKETS - 1]
        ceiling = [ceiling, start + 1].max

        steps = LevelLadder::FRACTIONS.transform_values do |fraction|
          pick(cumulative[level], start, ceiling, fraction, level)
        end

        [level.to_s, steps]
      end
    end

    def pick(counts, start, ceiling, fraction, level)
      want = start + ((ceiling - start) * fraction)
      found = (0...BUCKETS).find { |tolerance| counts[tolerance] >= want } || (BUCKETS - 1)
      found -= 1 while found.positive? && level < MAX_LEVEL && counts[found] >= ceiling
      found
    end

    def report(ladder)
      ladder.each do |scale, levels|
        @io.puts("  #{scale}: " + levels.map { |level, steps| "#{level}→#{steps.values.join("/")}" }.join(" "))
      end
    end
  end
end
