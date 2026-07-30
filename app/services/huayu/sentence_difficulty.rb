# frozen_string_literal: true

module Huayu
  class SentenceDifficulty
    SCALE = 1000
    PERCENTILE = 0.9
    MAX_GRADE = 7

    DAMP_THRESHOLD = 400.0
    MIN_WEIGHT = 0.15

    UNLEVELLED_FLOOR = 0.45
    UNLEVELLED_CEILING = 0.95

    def initialize
      @analyzer = TextAnalyzer.new
      @frequency = WordFrequency.instance
      @scores = {}
      @levels = load_levels
    end

    private

    def load_levels
      table = {}
      Lexeme.where(kind: %i[word character collocation]).pluck(:text, :data).each do |text, data|
        grade = LEVELS[data["tocfl_level"]] || data["tbcl_grade"]&.to_i
        table[text] = [grade, data["freq_rank"].to_i] if grade&.positive?
      end

      table
    end

    public

    def call(text, tokens: nil)
      units = tokens ? tokens.map { |t| t.respond_to?(:text) ? t.text : t.to_s } : @analyzer.segment(text)
      return 0 if units.empty?

      weighted = units.map { |unit| [score_for(unit), weight_for(unit)] }

      return 0 if weighted.empty?

      (percentile(weighted) * SCALE).round
    end

    private

    def score_for(unit)
      @scores[unit] ||= level_score(unit) || frequency_score(unit)
    end

    def level_score(unit)
      grade, rank = @levels[unit]
      return nil if grade.nil?

      band = 1.0 / MAX_GRADE
      within = rank.positive? ? [Math.log(rank + 1) / Math.log(20_000), 1.0].min : 0.5
      ((grade - 1) * band) + (band * within)
    end

    def frequency_score(text)
      per_million = @frequency.per_million(text)
      return UNLEVELLED_CEILING if per_million.zero?

      position = 1.0 - ([Math.log10(per_million + 1) / 3.0, 1.0].min)
      UNLEVELLED_FLOOR + ((UNLEVELLED_CEILING - UNLEVELLED_FLOOR) * position)
    end

    LEVELS = {"Novice1" => 1, "Novice2" => 2, "A1" => 3, "A2" => 4, "B1" => 5, "B2" => 6, "C" => 7}.freeze

    def weight_for(text)
      per_million = @frequency.per_million(text)
      return 1.0 if per_million <= DAMP_THRESHOLD

      [DAMP_THRESHOLD / per_million, MIN_WEIGHT].max
    end

    def percentile(weighted)
      sorted = weighted.sort_by(&:first)
      target = sorted.sum(&:last) * PERCENTILE
      running = 0.0
      sorted.each do |score, weight|
        running += weight
        return score if running >= target
      end

      sorted.last.first
    end
  end
end
