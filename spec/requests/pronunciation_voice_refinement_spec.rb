# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pronunciation voice refinement" do
  let!(:word) do
    create(:lexeme, kind: :word, text: "學校", readings: {"pinyin" => "xué xiào"}, meanings: {"en" => "school"})
  end

  before { allow_any_instance_of(Pronunciation::SkillRecorder).to(receive(:call)) }

  def grade_with(syllables)
    allow_any_instance_of(Pronunciation::AcousticBackend).to(
      receive(:grade).and_return({"syllables" => syllables, "overall" => 80})
    )
    post(pronunciation_grade_path, params: {lexeme_id: word.id, text: "學校", expected: "[]", tonal: "true"})
  end

  it "feeds every syllable that carries a curve and a tone back into the calibrated profile as absolute pitch" do
    voice = warm_up!
    calls = []
    allow(Pronunciation::Calibration).to(receive(:refine!)) { |profile, **kw|
      calls << [profile.id, kw]
      profile
    }

    grade_with(
      [
        {
          "level" => "green",
          "overall" => 90,
          "tone" => 2,
          "contour" => {"curve" => [0.0, 12.0]},
          "features" => {"f0_ref_hz" => 100.0}
        },
        {"level" => "green", "overall" => 85, "tone" => 4, "contour" => {"curve" => [0.0]}, "features" => {}},
        {"level" => "green", "overall" => 70, "tone" => nil, "contour" => {"curve" => [1.0]}},
        {"level" => "amber", "overall" => 60, "tone" => 1}
      ]
    )

    expect(response).to(have_http_status(:ok))
    expect(calls).to(
      eq(
        [
          [voice.id, {f0_values: [100.0, 200.0], tone: 2, score: 90}],
          [voice.id, {f0_values: [], tone: 4, score: 85}]
        ]
      )
    )
  end

  it "leaves calibration alone for an account without a voice profile" do
    expect(Pronunciation::Calibration).not_to(receive(:refine!))

    grade_with(
      [
        {
          "level" => "green",
          "overall" => 90,
          "tone" => 2,
          "contour" => {"curve" => [0.0]},
          "features" => {"f0_ref_hz" => 100.0}
        }
      ]
    )

    expect(response).to(have_http_status(:ok))
  end
end
