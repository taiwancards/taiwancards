# frozen_string_literal: true

module Pronunciation
  class GradeAttempt
    KINDS = %i[word character sentence].freeze

    def initialize(user:, voice:, tonal: true)
      @user = user
      @voice = voice
      @tonal = tonal
    end

    def call(audio:, text:, expected:, takes:, lexeme_id:, schedule: true, content_type: nil)
      result = Admission.take do
        AcousticBackend.new(tonal: @tonal, voice: @voice).grade(audio:, text:, syllables: expected, takes:)
      end

      return result if result == :busy || result.nil? || result["status"] == "retry"

      lexeme = Lexeme.where(kind: KINDS).find_by(id: lexeme_id)
      record_attempt(lexeme, result, schedule:) if lexeme
      keep_recording(audio, text, expected, lexeme, result, content_type)
      refine_voice(result)
      result
    end

    private

    def record_attempt(lexeme, result, schedule:)
      syllables = Array(result["syllables"])
      SkillRecorder.new(@user, lexeme).call(syllables, flow: result["flow"])
      return if lexeme.sentence?
      return unless schedule

      ok = syllables.any? && syllables.all? { |syllable| syllable["level"] == "green" }
      memory = Lexemes::Activator.new(user: @user).activate(lexeme, :tone)
      Lexemes::ReviewProcessor.new.call(memory, rating: ok ? "good" : "again")
    end

    def keep_recording(audio, text, expected, lexeme, result, content_type)
      Keeper.new(@user).keep(audio:, text:, result:, expected:, lexeme:, content_type:)
    rescue StandardError => error
      Rails.logger.warn("pronunciation recording not kept: #{error.class}")
    end

    def refine_voice(result)
      voice = @voice || VoiceProfile.find_or_create_by!(user: @user)

      Array(result["syllables"]).each do |syllable|
        next if syllable.dig("contour", "curve").blank?

        if syllable["tone"].present? && syllable["overall"].to_i >= Calibration::GOOD_ENOUGH_TO_LEARN_FROM
          Calibration.refine!(
            voice,
            f0_values: absolute_pitch(syllable),
            tone: syllable["tone"],
            score: syllable["overall"]
          )
        else
          Calibration.absorb!(voice, f0_values: absolute_pitch(syllable))
        end
      end

    rescue StandardError => error
      Rails.logger.warn("voice profile not refined: #{error.class}")
    end

    def absolute_pitch(syllable)
      reference = syllable.dig("features", "f0_ref_hz")
      return [] if reference.blank?

      syllable.dig("contour", "curve").map { |semitones| reference * (2 ** (semitones / 12.0)) }
    end
  end
end
