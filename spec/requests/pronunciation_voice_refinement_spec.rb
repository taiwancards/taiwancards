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

  it "starts a voice profile silently and learns the register from every voiced syllable" do
    syllable = {
      "level" => "amber",
      "overall" => 40,
      "tone" => 3,
      "contour" => {"curve" => Array.new(30, 0.0)},
      "features" => {"f0_ref_hz" => 120.0}
    }

    expect { 7.times { grade_with([syllable]) } }.to(change(VoiceProfile, :count).by(1))

    voice = VoiceProfile.find_by(user: @authenticated_user)
    expect(voice).to(be_calibrated)
    expect(voice.f0_median).to(be_within(VoiceProfile::BIN_WIDTH).of(120))
    expect(voice.f0_by_tone).to(be_empty)
  end

  it "stops absorbing untrusted syllables once the register is known" do
    voice = warm_up!
    frames = voice.n_calibration_frames

    grade_with(
      [
        {
          "level" => "amber",
          "overall" => 40,
          "tone" => 3,
          "contour" => {"curve" => [0.0]},
          "features" => {"f0_ref_hz" => 120.0}
        }
      ]
    )

    expect(voice.reload.n_calibration_frames).to(eq(frames))
  end
end
