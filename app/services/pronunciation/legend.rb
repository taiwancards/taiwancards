# frozen_string_literal: true

module Pronunciation
  class Legend
    def initialize(verdict: Verdict.new, locale: I18n.locale)
      @verdict = verdict
      @coach = Coach.new(locale:)
    end

    def rows
      b = @verdict.bounds("overall")
      from = {"green" => b["green"], "amber" => b["red"], "red" => b["dark"] + 1, "dark" => 0}

      Verdict::LEVELS.map do |level|
        {
          "level" => level,
          "name" => @coach.level_name(level),
          "note" => @coach.level_note(level),
          "from" => from[level]
        }
      end
    end
  end
end
