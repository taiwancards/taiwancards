# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tone scoring and the speaker's register" do
  let(:analyzer) { Pronunciation::Acoustic::Analyzer.new(store) }
  let(:store) { instance_double(Pronunciation::TemplateStore) }

  let(:center) { [1.5, 1.1, 0.8, 0.8, 0.8, 0.6, 0.3, 0.3, -0.3, -1.2, -2.2, -3.2, -4.5, -5.9, -7.0, -8.2] }
  let(:template) do
    {
      "tone" => 4,
      "tone_contour" => {"center" => center, "sigma" => Array.new(16, 0.5)},
      "tone_range" => {"median" => 9.8, "sigma" => 1.05},
      "tone_slope" => {"median" => -9.7, "sigma" => 2.2},
      "f0_register" => {"median" => 2.77, "sigma" => 0.7}
    }
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

  it "gives full marks to a contour that lands on the reference" do
    expect(score(curve: center)).to(be >= 95)
  end

  it "keeps the contour primary when the register is off" do
    four_sigma = template.dig("f0_register", "median") + (4 * template.dig("f0_register", "sigma"))
    matched = score(curve: center, register: four_sigma)
    mismatched = score(curve: center.reverse, register: template.dig("f0_register", "median"))

    expect(matched).to(be > mismatched)
  end

  it "does not let a matching register rescue a contour of the wrong shape" do
    wrong = center.reverse
    blind = score(curve: wrong)
    helped = score(curve: wrong, register: template.dig("f0_register", "median"))

    expect(helped).to(be <= blind)
  end

  it "still fails a contour of the wrong shape" do
    flat = Array.new(16, 0.0)
    rising = 16.times.map { |i| -4.0 + (8.0 * i / 15) }

    expect(score(curve: flat)).to(be < 20)
    expect(score(curve: rising)).to(be < 20)
  end

  it "caps the register contribution however far off the reference is" do
    median = template.dig("f0_register", "median")

    expect(score(curve: center, register: median + 100)).to(eq(score(curve: center, register: median + 1000)))
    expect(score(curve: center, register: median + 1000)).to(be > score(curve: center.reverse))
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
