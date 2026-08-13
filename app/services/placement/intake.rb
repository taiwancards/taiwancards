# frozen_string_literal: true

module Placement
  class Intake
    QUESTIONS = {
      "experience" => %w[none some year more],
      "script" => %w[none pinyin zhuyin both],
      "characters" => %w[none few read write],
      "variety" => %w[none unsure china taiwan]
    }.freeze

    EXPERIENCE_PRIOR = {"none" => 1, "some" => 2, "year" => 3, "more" => 5}.freeze
    CHARACTER_PRIOR = {"none" => 1, "few" => 2, "read" => 4, "write" => 5}.freeze

    SANITY_BUDGET = 3
    SHORT_BUDGET = 8
    FULL_BUDGET = 24

    SOUND_AXES = %w[listening tones syllables].freeze
    READING_AXES = %w[characters lexis vocab_size grammar sentences].freeze

    Result = Data.define(:answers, :prior, :axes, :script, :budget, :mode) do
      def axis?(name) = axes.include?(name.to_s)

      def sanity? = mode == "sanity"

      def script?(name) = script == name.to_s

      def reads? = answers["characters"] != "none"

      def simplified? = answers["variety"] == "china"
    end

    def self.call(...) = new.call(...)

    def call(answers, short: false)
      answers = sanitize(answers)
      mode = mode_for(answers, short)

      Result.new(
        answers:,
        prior: prior_for(answers),
        axes: axes_for(answers, mode),
        script: script_for(answers),
        budget: budget_for(mode),
        mode:
      )
    end

    private

    def sanitize(answers)
      QUESTIONS.to_h do |name, allowed|
        value = answers.is_a?(Hash) ? (answers[name] || answers[name.to_sym]).to_s : ""
        [name, allowed.include?(value) ? value : allowed.first]
      end
    end

    def mode_for(answers, short)
      return "sanity" if answers["experience"] == "none" && answers["characters"] == "none"
      return "short" if short

      "full"
    end

    def budget_for(mode)
      case mode
      when "sanity"
        SANITY_BUDGET
      when "short"
        SHORT_BUDGET
      else
        FULL_BUDGET
      end
    end

    def prior_for(answers)
      [EXPERIENCE_PRIOR.fetch(answers["experience"]), CHARACTER_PRIOR.fetch(answers["characters"])].min
    end

    def axes_for(answers, mode)
      return %w[listening lexis] if mode == "sanity"

      axes = ["listening"]
      axes << "tones" unless answers["experience"] == "none"
      axes << "syllables" if answers["script"] != "none"
      axes.concat(READING_AXES) if answers["characters"] != "none"
      axes << "script" unless answers["script"] == "none"
      axes << "taiwan" if answers["variety"] == "china" || answers["characters"] != "none"
      axes << "traditional" if answers["variety"] == "china"
      axes << "writing" if answers["characters"] == "write"
      axes
    end

    def script_for(answers)
      case answers["script"]
      when "zhuyin", "both"
        "zhuyin"
      when "pinyin"
        "pinyin"
      else
        "none"
      end
    end
  end
end
