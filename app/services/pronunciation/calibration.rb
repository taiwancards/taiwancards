# frozen_string_literal: true

module Pronunciation
  module Calibration
    TONE_STEPS = [
      {id: "tone_1", key: "ma1", char: "媽", zhuyin: "ㄇㄚ", pinyin: "mā", tone: 1},
      {id: "tone_2", key: "ma2", char: "麻", zhuyin: "ㄇㄚˊ", pinyin: "má", tone: 2},
      {id: "tone_3", key: "ma3", char: "馬", zhuyin: "ㄇㄚˇ", pinyin: "mǎ", tone: 3},
      {id: "tone_4", key: "ma4", char: "罵", zhuyin: "ㄇㄚˋ", pinyin: "mà", tone: 4}
    ].freeze

    PROMPTS = [
      {id: "vowels", kind: :sustained},
      {id: "rise", kind: :intonation},
      {id: "fall", kind: :intonation},
      *TONE_STEPS.map { |step| {id: step[:id], text: step[:char], kind: :tone, tone: step[:tone]} }
    ].freeze

    GOOD_ENOUGH_TO_LEARN_FROM = 80

    module_function

    def prompts_for(locale)
      language = locale.to_s.split("-").first
      language = "en" unless I18n.locale_available?(language)

      PROMPTS.map do |step|
        words = I18n.t("pron.warmup.prompts.#{step[:id]}", locale: language)
        prompt = {id: step[:id], text: step[:text] || words.fetch(:text), hint: words.fetch(:hint), kind: step[:kind]}
        step[:tone] ? prompt.merge(tone: step[:tone]) : prompt
      end
    end

    def ingest(profile, analysis, kind:, tone: nil, locale: nil)
      return {ok: false, error: "too_short"} if analysis.blank? || analysis[:f0_voiced].blank?

      if kind.to_s == "sustained"
        f3 = analysis[:f3_median]
        profile.f3_ref = f3 if f3 && VoiceProfile::PLAUSIBLE_F3.cover?(f3)
        profile.f1_ref = analysis[:f1_median] if analysis[:f1_median]
        profile.f2_ref = analysis[:f2_median] if analysis[:f2_median]
      end

      profile.observe_f0!(analysis[:f0_voiced], tone: tone.presence&.to_i, replace: kind.to_s == "tone")
      profile.calibration_locale ||= locale
      profile.calibrated_at = Time.current if profile.f3_ref.present?
      profile.save!

      {ok: true, summary: profile.summary}
    end

    def absorb!(profile, f0_values:)
      return profile if profile.calibrated? || f0_values.blank?

      profile.observe_f0!(Array(f0_values).map { |hz| profile.octave_corrected(hz) })
      profile.save!
      profile
    end

    def refine!(profile, f0_values:, tone:, score:, threshold: GOOD_ENOUGH_TO_LEARN_FROM)
      return profile if score.to_i < threshold || tone.blank?

      profile.observe_f0!(Array(f0_values).map { |hz| profile.octave_corrected(hz) }, tone: tone)
      profile.n_attempts = profile.n_attempts + 1
      profile.save!
      profile
    end
  end
end
