# frozen_string_literal: true

require "rails_helper"

RSpec.describe VoiceProfile do
  let(:profile) { described_class.create!(user: create(:user)) }

  def hear(tone, hz, frames: 40)
    profile.observe_f0!(Array.new(frames, hz), tone: tone)
    profile.save!
  end

  it "puts the reference at the center of every tone it has heard" do
    hear(1, 240.0)
    hear(2, 200.0)
    hear(3, 160.0)
    hear(4, 220.0)

    expect(profile.reference_hz).to(be_within(3).of((240 * 200 * 160 * 220) ** 0.25))
  end

  it "does not let the two extremes stand in for the whole range" do
    hear(1, 240.0)
    hear(3, 160.0)
    two_anchors = profile.reference_hz

    hear(2, 200.0)
    hear(4, 220.0)

    expect(profile.reference_hz).not_to(be_within(2).of(two_anchors))
  end

  it "measures the span between the high and the low tone" do
    hear(1, 240.0)
    hear(3, 120.0)

    expect(profile.tone_span_semitones).to(be_within(1).of(12))
  end

  it "refuses a span when the learner put the tones the wrong way round" do
    hear(1, 120.0)
    hear(3, 240.0)

    expect(profile.tone_span_semitones).to(be_nil)
    expect(profile).not_to(be_tone_calibrated)
  end

  it "ignores a step too short to measure" do
    hear(1, 240.0, frames: 4)

    expect(profile.tone_anchor(1)).to(be_nil)
  end

  it "reports how far the learner moves on the tones that move" do
    profile.observe_f0!(Array.new(20, 160.0) + Array.new(20, 240.0), tone: 2)
    profile.save!

    expect(profile.tone_excursion_semitones).to(be_within(2).of(7))
  end
end
