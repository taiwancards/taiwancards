# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tone scoring and the speaker's register" do
  let(:analyzer) { Pronunciation::Acoustic::Analyzer.new(store) }
  let(:store) { instance_double(Pronunciation::TemplateStore) }

  let(:center) { [1.5, 1.1, 0.8, 0.8, 0.8, 0.6, 0.3, 0.3, -0.3, -1.2, -2.2, -3.2, -4.5, -5.9, -7.0, -8.2] }
  let(:template) do
    spread = {
      "mark_onset" => 0.8,
      "mark_q1" => 1.0,
      "mark_mid" => 1.3,
      "mark_q3" => 1.8,
      "mark_end" => 2.2,
      "mark_early" => 0.9,
      "mark_late" => 1.2,
      "mark_curve" => 0.5,
      "mark_minpos" => 0.15
    }
    marks = Pronunciation::Acoustic::ToneMarks
      .of(center, 2.77)
      .to_h { |field, value| [field, {"median" => value, "mad" => spread[field], "sigma" => spread[field]}] }

    {
      "tone" => 4,
      "tone_contour" => {"center" => center, "sigma" => Array.new(16, 0.5)},
      "tone_range" => {"median" => 9.8, "sigma" => 1.05},
      "tone_slope" => {"median" => -9.7, "sigma" => 2.2},
      "f0_register" => {"median" => 2.77, "sigma" => 0.7}
    }.merge(marks)
  end

  def features(curve:, register: nil)
    {
      "tone_curve" => curve,
      "tone_range" => curve.max - curve.min,
      "tone_slope" => curve.last - curve.first,
      "duration_ms" => 300.0,
      "f0_ref_hz" => 200.0,
      "f0_register" => register
    }
  end

  def score(curve:, register: nil)
    analyzer.send(:tone_axis, features(curve:, register:), template, "taiwan")["score"]
  end

  def strain(curve:, register: nil)
    analyzer.send(:tone_axis, features(curve:, register:), template, "taiwan")["z"]
  end

  it "gives full marks to a contour that lands on the reference" do
    expect(score(curve: center, register: template.dig("f0_register", "median"))).to(be >= 95)
  end

  it "keeps the contour primary when the register is off" do
    four_sigma = template.dig("f0_register", "median") + (4 * template.dig("f0_register", "sigma"))
    matched = score(curve: center, register: four_sigma)
    mismatched = score(curve: center.reverse, register: template.dig("f0_register", "median"))

    expect(matched).to(be > mismatched)
  end

  it "does not let a matching register rescue a contour of the wrong shape" do
    median = template.dig("f0_register", "median")
    right = strain(curve: center, register: median)
    wrong = center.reverse

    expect(strain(curve: wrong)).to(be > right * 3)
    expect(strain(curve: wrong, register: median)).to(be > right * 3)
  end

  it "still fails a contour of the wrong shape" do
    median = template.dig("f0_register", "median")
    right = strain(curve: center, register: median)
    flat = strain(curve: Array.new(16, 0.0), register: median)
    rising = strain(curve: 16.times.map { |i| -4.0 + (8.0 * i / 15) }, register: median)

    expect(flat).to(be > right * 3)
    expect(rising).to(be > right * 3)
  end

  it "charges the height in proportion to how far off it is, with no ceiling" do
    median = template.dig("f0_register", "median")
    sigma = template.dig("f0_register", "sigma")
    on_pitch = score(curve: center, register: median)
    near = score(curve: center, register: median + (6 * sigma))
    far = score(curve: center, register: median + (14 * sigma))

    expect(near).to(be < on_pitch)
    expect(far).to(be < near)
  end

  it "forgives the height altogether when no register was heard" do
    median = template.dig("f0_register", "median")

    expect(score(curve: center)).to(be >= score(curve: center, register: median + 6.0))
  end

  describe "when the profile has no tone anchors" do
    let(:backend) { Pronunciation::AcousticBackend.new(store: store, voice: voice) }
    let(:voice) { VoiceProfile.new(f0_hist: [], calibrated_at: Time.current, f3_ref: 2900) }

    it "leaves the register out of the measurement entirely" do
      expect(voice.tone_calibrated?).to(be(false))
      expect(backend.send(:register, {"f0_ref_hz" => 200.0})).to(be_nil)
    end
  end
end
