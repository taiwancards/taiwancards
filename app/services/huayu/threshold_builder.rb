# frozen_string_literal: true

module Huayu
  class ThresholdBuilder
    COLUMNS = LevelThresholds::SCALES.flat_map { |scale| LevelThresholds.columns_for(scale) }.freeze
    BATCH = 20_000

    def initialize(io: $stdout)
      @io = io
      @analyzer = TextAnalyzer.new
    end

    def call
      LevelThresholds.reset!
      @thresholds = LevelThresholds.instance

      composite = Lexeme.where(kind: %i[sentence collocation])
      atomic = Lexeme.where(kind: %i[word character measure_word])
      total = composite.count + atomic.count

      RakeProgress.counter(total, "thresholds", every: 5_000) do |tick|
        composite.in_batches(of: BATCH) do |relation|
          rows = relation.pluck(:id, :text, :data, :kind)
          computed = ParallelMap.call(rows, warmup: method(:warm)) { |row| composite_row(row) }

          write(computed.compact)
          rows.length.times { tick.call }
        end

        atomic.in_batches(of: BATCH) do |relation|
          rows = relation.pluck(:id, :data)
          write(rows.map { |id, data| [id, *COLUMNS.map { |column| atomic_values(data).fetch(column) }] })
          rows.length.times { tick.call }
        end
      end

      report
    end

    private

    TYPES = COLUMNS.to_h { |column| [column.to_s, "smallint"] }.freeze

    def warm
      thresholds
      @analyzer.segment("暖機")
    end

    def thresholds = @thresholds ||= LevelThresholds.instance

    def composite_row(row)
      id, text, data, kind = row
      units = segments_of(text, data, kind)
      return nil if units.empty?

      values = LevelThresholds::SCALES.reduce({}) { |memo, s| memo.merge(thresholds.for_tokens(s, units)) }
      [id, *COLUMNS.map { |column| values.fetch(column) }]
    end

    def atomic_values(data)
      grade = data["tbcl_grade"].to_i
      position = SentenceProfile::TOCFL_LEVELS.index(data["tocfl_level"])

      thresholds
        .for_level("tbcl", grade.positive? ? grade : nil)
        .merge(thresholds.for_level("tocfl", position ? position + 1 : nil))
    end

    def segments_of(text, data, kind)
      stored = data["segments"]
      return stored if stored.is_a?(Array) && stored.any?

      collocation = kind == Lexeme.kinds.fetch("collocation")
      @analyzer.segment(text, excluding: collocation ? text : nil)
    end

    def write(rows)
      Bulk.patch(target: "lexemes", columns: TYPES, rows: rows)
    end

    def report
      LevelThresholds::SCALES.each do |scale|
        tallies = LevelLadder::STEPS.map.with_index do |step, index|
          column = LevelThresholds::COLUMNS.fetch(scale).fetch(step)
          "count(*) FILTER (WHERE #{column} < #{LevelThresholds::NEVER}) AS step#{index}"
        end

        counts = Lexeme.connection.select_rows("SELECT #{tallies.join(", ")} FROM lexemes").first
        @io.puts(format("  %-6s reachable per step: %s", scale, counts.join(" / ")))
      end
    end
  end
end
