# frozen_string_literal: true

module Pronunciation
  class SkillRecorder
    def initialize(user, lexeme)
      @user = user
      @lexeme = lexeme
    end

    def call(syllables)
      return if @user.nil?

      now = Time.current
      ActiveRecord::Base.transaction do
        syllables.each_with_index do |syllable, index|
          log(syllable, index, now)
          accumulate(syllable, now)
        end
      end
    end

    private

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

    def accumulate(syllable, now)
      key = syllable["key"].presence or return
      return if syllable["overall"].nil?

      skill(key).record!(
        overall: syllable["overall"],
        level: syllable["level"],
        parts: (syllable["cells"] || {}).transform_values { |cell| cell["score"] },
        deviations: syllable["deviations"] || {},
        codes: syllable["codes"] || [],
        heard: syllable["best_match"],
        at: now
      )
    end

    def skill(key)
      SyllableSkill.transaction(requires_new: true) { SyllableSkill.claim(@user, key) }
    rescue ActiveRecord::RecordNotUnique
      SyllableSkill.find_by!(user: @user, syllable_key: key)
    end
  end
end
