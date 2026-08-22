# frozen_string_literal: true

module Pronunciation
  class SkillRecorder
    def initialize(user, lexeme)
      @user = user
      @lexeme = lexeme
    end

    def call(syllables, flow: nil)
      return if @user.nil?

      now = Time.current
      junctions = junctions_by_syllable(flow)
      ActiveRecord::Base.transaction do
        syllables.each_with_index do |syllable, index|
          log(syllable, index, now)
          accumulate(syllable, junctions[index], now)
        end
      end
    end

    private

    def junctions_by_syllable(flow)
      Array(flow && flow["junctions"]).to_h { |junction| [junction["index"].to_i + 1, junction] }
    end

    def log(syllable, index, now)
      cells = syllable["cells"] || {}

      PronunciationAttempt.create!(
        user: @user,
        lexeme: @lexeme,
        ok: syllable["level"] == "green",
        level: syllable["level"],
        recognized: syllable["best_match"],
        syllable_key: syllable["key"],
        syllable_index: index,
        score_overall: syllable["overall"],
        score_initial: cells.dig("initial", "score"),
        score_medial: cells.dig("medial", "score"),
        score_final: cells.dig("final", "score"),
        score_tone: cells.dig("tone", "score"),
        best_match: syllable["best_match"],
        rejected: syllable["rejected"].present?,
        created_at: now
      )
    end

    def accumulate(syllable, junction, now)
      key = syllable["key"].presence or return
      return if syllable["overall"].nil?

      skill(key).record!(
        overall: syllable["overall"],
        level: syllable["level"],
        parts: (syllable["cells"] || {}).transform_values { |cell| cell["score"] },
        deviations: syllable["deviations"] || {},
        codes: Array(syllable["codes"]) + junction_codes(junction),
        heard: syllable["best_match"],
        flow: junction && junction["score"],
        at: now
      )
    end

    def junction_codes(junction)
      code = junction && junction["code"]
      code.nil? || code.end_with?(".ok") ? [] : [code]
    end

    def skill(key)
      SyllableSkill.transaction(requires_new: true) { SyllableSkill.claim(@user, key) }
    rescue ActiveRecord::RecordNotUnique
      SyllableSkill.find_by!(user: @user, syllable_key: key)
    end
  end
end
