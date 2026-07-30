# frozen_string_literal: true

module Pronunciation
  module Calibration
    TONE_STEPS = [
      {id: "tone_1", key: "ma1", char: "媽", zhuyin: "ㄇㄚ", pinyin: "mā", tone: 1},
      {id: "tone_2", key: "ma2", char: "麻", zhuyin: "ㄇㄚˊ", pinyin: "má", tone: 2},
      {id: "tone_3", key: "ma3", char: "馬", zhuyin: "ㄇㄚˇ", pinyin: "mǎ", tone: 3},
      {id: "tone_4", key: "ma4", char: "罵", zhuyin: "ㄇㄚˋ", pinyin: "mà", tone: 4}
    ].freeze

    PROMPTS = {
      "ru" => [
        {
          id: "vowels",
          text: "и — а — у",
          hint: "тяните каждый звук полторы секунды",
          kind: :sustained
        },
        {id: "rise", text: "Это правда?!", hint: "с удивлением", kind: :intonation},
        {
          id: "fall",
          text: "Да, это правда.",
          hint: "спокойно, с точкой в конце",
          kind: :intonation
        },
        {
          id: "tone_1",
          text: "媽",
          hint: "ровно и высоко: возьмите ноту чуть выше обычной речи и держите её, не отпуская",
          kind: :tone,
          tone: 1
        },
        {
          id: "tone_2",
          text: "麻",
          hint: "снизу вверх, как переспрос «Да?» — голос идёт вверх и не останавливается",
          kind: :tone,
          tone: 2
        },
        {
          id: "tone_3",
          text: "馬",
          hint: "в самый низ голоса и чуть обратно вверх, как задумчивое «ну-у…»",
          kind: :tone,
          tone: 3
        },
        {
          id: "tone_4",
          text: "罵",
          hint: "резко сверху вниз, как окрик «Стой!»",
          kind: :tone,
          tone: 4
        }
      ],
      "en" => [
        {
          id: "vowels",
          text: "ee — ah — oo",
          hint: "hold each sound for about a second and a half",
          kind: :sustained
        },
        {id: "rise", text: "Really?!", hint: "with surprise", kind: :intonation},
        {id: "fall", text: "Yes, it is.", hint: "calmly, ending flat", kind: :intonation},
        {
          id: "tone_1",
          text: "媽",
          hint: "level and high: hold one steady note a little above your speaking voice",
          kind: :tone,
          tone: 1
        },
        {
          id: "tone_2",
          text: "麻",
          hint: "rising, like a questioning \"Huh?\" — the voice keeps climbing",
          kind: :tone,
          tone: 2
        },
        {
          id: "tone_3",
          text: "馬",
          hint: "down to the bottom of your voice and a little back up, like a doubtful \"Well…\"",
          kind: :tone,
          tone: 3
        },
        {
          id: "tone_4",
          text: "罵",
          hint: "falling sharply from high to low, like a firm \"Stop!\"",
          kind: :tone,
          tone: 4
        }
      ]
    }.freeze

    GOOD_ENOUGH_TO_LEARN_FROM = 80

    module_function

    def prompts_for(locale)
      PROMPTS[locale.to_s.split("-").first] || PROMPTS["en"]
    end

    def ingest(profile, analysis, kind:, tone: nil, locale: nil)
      return {ok: false, error: "too_short"} if analysis.blank? || analysis[:f0_voiced].blank?

      if kind.to_s == "sustained"
        profile.f3_ref = analysis[:f3_median] if analysis[:f3_median]
        profile.f1_ref = analysis[:f1_median] if analysis[:f1_median]
        profile.f2_ref = analysis[:f2_median] if analysis[:f2_median]
      end

      profile.observe_f0!(analysis[:f0_voiced], tone: tone.presence&.to_i, replace: kind.to_s == "tone")
      profile.calibration_locale ||= locale
      profile.calibrated_at = Time.current if profile.f3_ref.present?
      profile.save!

      {ok: true, summary: profile.summary}
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
