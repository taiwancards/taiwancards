# frozen_string_literal: true

module Pronunciation
  class Coach
    SCOPE = "pron"

    CUE_SCOPE = {
      "initial" => "initials",
      "medial" => "medials",
      "final" => "rimes",
      "tone" => "tones"
    }.freeze

    def initialize(locale: I18n.locale)
      @locale = locale
    end

    QUIET = %w[green gray none].freeze

    def part(descriptor, score, level, code, vars)
      key = code.to_s.end_with?(".ok") ? "near" : code
      quiet = QUIET.include?(level)

      {
        "label" => t("parts.#{descriptor["id"]}"),
        "problem" => quiet ? nil : t("codes.#{key}", **symbolize(vars)),
        "advice" => quiet ? nil : t("fixes.#{key}", **symbolize(vars)),
        "cue" => cue_for(descriptor),
        "score" => score,
        "level" => level
      }.compact
    end

    def level_note(level) = t("levels.#{level}.note")

    def advisory(code, vars = nil) = t("codes.#{code}", default: nil, **symbolize(vars))

    def level_name(level) = t("levels.#{level}.name")

    def confusion(expected, got)
      return nil if expected.blank? || got.blank? || expected == got

      es, et = Acoustic::Syllables.parse_key(expected)
      gs, gt = Acoustic::Syllables.parse_key(got)
      return nil unless es && gs

      key = if es == gs
        "tone_only"
      else
        (et == gt) ? "segments_only" : "both"
      end

      t("confusion.#{key}", syllable: gs, tone: gt, expected_syllable: es, expected_tone: et)
    end

    private

    def cue_for(descriptor)
      scope = CUE_SCOPE[descriptor["id"]]
      return nil if scope.nil?

      name = descriptor["empty_rime"] ? "empty" : descriptor["pinyin"]
      return nil if name.blank?

      t("#{scope}.#{name}", default: nil)
    end

    def symbolize(vars)
      (vars || {}).to_h { |k, v| [k.to_sym, v.is_a?(Array) ? v.join(" / ") : v] }
    end

    def t(key, **args)
      I18n.t("#{SCOPE}.#{key}", locale: @locale, **args)
    end
  end
end
