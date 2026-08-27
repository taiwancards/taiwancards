# frozen_string_literal: true

module Lexemes
  # Places a text on a graded scale from the pieces a reader already knows: a unit that carries a
  # level of its own counts whole, anything else is read character by character. The level is the
  # lowest one covering COVERAGE of those pieces, and only when nothing sticks out more than SPREAD
  # levels above it — so a long term is filed where most of it sits rather than where its rarest
  # character does. Below four characters the allowance is inert: ceil(3 * 0.75) == 3.
  class LevelScale
    HAN = /\p{Han}/
    COVERAGE = 0.75
    SPREAD = 2

    Placement = Data.define(:index, :exact, :unknown)
    BLANK = Placement.new(index: nil, exact: false, unknown: 0)

    def self.vocabulary
      tocfl = {}
      tbcl = {}

      Lexeme.where(kind: %i[word character]).pluck(:text, :data).each do |text, data|
        position = SentenceProfile::TOCFL_LEVELS.index(data["tocfl_level"])
        tocfl[text] = [tocfl[text], position + 1].compact.min if position

        grade = data["tbcl_grade"]&.to_i
        tbcl[text] = [tbcl[text], grade].compact.min if grade&.positive?
      end

      {
        "tocfl" => new(tocfl, ceiling: SentenceProfile::TOCFL_LEVELS.length),
        "tbcl" => new(tbcl, ceiling: SentenceProfile::TBCL_GRADES.length)
      }
    end

    def initialize(table, ceiling:)
      @table = table
      @ceiling = ceiling
    end

    def place(units, excluding: nil)
      levels = atoms(units, excluding)
      return BLANK if levels.empty?

      known = levels.compact
      target = (levels.length * COVERAGE).ceil
      return BLANK if known.length < target

      unknown = levels.length - known.length
      worst = [known.max, @ceiling].min
      counts = Array.new(@ceiling + 1, 0)
      known.each { |level| counts[[level, @ceiling].min] += 1 }

      running = 0
      (1..@ceiling).each do |level|
        running += counts[level]
        next if running < target || worst > level + SPREAD

        return Placement.new(index: level, exact: unknown.zero? && worst <= level, unknown:)
      end

      BLANK
    end

    private

    def atoms(units, excluding)
      units.flat_map do |unit|
        level = @table[unit] unless unit == excluding
        next [level] if level

        unit.chars.select { |char| char.match?(HAN) }.map { |char| @table[char] }
      end
    end
  end
end
