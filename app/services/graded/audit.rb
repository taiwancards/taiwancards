# frozen_string_literal: true

module Graded
  class Audit
    TARGET = 0.95
    FLOOR = 0.90
    LINES = 10

    Report = Data.define(:tier, :text, :rate, :outside, :unnoted, :issues) do
      def clean? = issues.empty?

      def to_s = format("%-10s %-10s %5.1f%% %s", tier, text, rate * 100, issues.join("; "))
    end

    def initialize(guard: Huayu::ChinaGuard.new)
      @guard = guard
    end

    def call = Library.tiers.flat_map { |tier| audit(tier) }

    def audit(tier)
      level = Levels.find(tier)
      return [] if level.nil?

      Library.texts(tier).map { |text| inspect_text(level, text) }
    end

    private

    def inspect_text(level, text)
      cover = level.cover.call(text.body)
      outside = cover.missing
      unnoted = outside.reject { |word| text.notes.any? { |note| note.zh.include?(word) } }

      Report.new(
        tier: level.id,
        text: text.id,
        rate: cover.rate,
        outside: outside,
        unnoted: unnoted,
        issues: faults(level, text, cover, unnoted)
      )
    end

    def faults(level, text, cover, unnoted)
      issues = []
      issues << format("coverage %.1f%% below %d%%", cover.rate * 100, FLOOR * 100) if cover.rate < FLOOR
      issues << "no note for #{unnoted.join(" ")}" if unnoted.any?
      issues << "#{text.sentences} lines" if text.sentences < LINES
      issues << "missing title" if text.zh.blank? || text.titles["en"].blank? || text.titles["ru"].blank?
      issues.concat(translations(text))
      issues.concat(script(text))
      issues
    end

    def translations(text)
      missing = text.lines.reject { |line| line.names["en"].present? && line.names["ru"].present? }
      missing.any? ? ["#{missing.size} lines without a translation"] : []
    end

    def script(text)
      offender = @guard.offender(text.body)
      simplified = Huayu::SimpToTrad.available? ? strays(text.body) : []

      issues = []
      issues << "China wording #{offender}" if offender
      issues << "simplified #{simplified.join(" ")}" if simplified.any?
      issues
    end

    def strays(body)
      table = Huayu::SimpToTrad.table
      body.each_char.select { |char| table[char].present? && table[char] != char && traditional.exclude?(char) }.uniq
    end

    def traditional
      @traditional ||= (Levels.all.flat_map(&:items).join + Levels::NAMES.join).chars.to_set
    end
  end
end
