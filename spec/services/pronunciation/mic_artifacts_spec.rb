# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recording artifacts" do
  let(:rate) { 48_000 }
  let(:noise) { Random.new(20_260_725) }

  def room(ms, level: 0.0005)
    Array.new((rate * ms / 1000.0).round) { ((noise.rand * 2) - 1) * level }
  end

  def breath(ms, level)
    Array.new((rate * ms / 1000.0).round) do |i|
      ((noise.rand * 2) - 1) * level * (0.6 + (0.4 * Math.cos(2 * Math::PI * 3000 * i / rate)))
    end
  end

  def vowel(ms, hz: 130.0, level: 0.25)
    Array.new((rate * ms / 1000.0).round) do |i|
      t = i.to_f / rate
      level *
        (Math.sin(2 * Math::PI * hz * t) +
          (0.6 * Math.sin(4 * Math::PI * hz * t)) +
          (0.3 * Math.sin(2 * Math::PI * 700 * t)))
    end
  end

  def click(level) = Array.new(60) { |i| level * Math.exp(-i / 12.0) * (i.even? ? 1 : -1) }

  def aspirated = breath(8, 0.05) + breath(95, 0.012) + vowel(320) + room(300)

  def analyzed(samples) = Pronunciation::Acoustic::Features.analyze(samples, rate)

  def vot_of(samples)
    an = analyzed(samples)
    span = Pronunciation::Acoustic::Features.speech_bounds(an)
    Pronunciation::Acoustic::Features.extract(an, span, initial: "k", utterance_initial: true)
  end

  it "does not take a microphone click for the start of the syllable" do
    an = analyzed(click(0.3) + room(500) + aspirated)
    low, = Pronunciation::Acoustic::Features.speech_bounds(an)

    expect(low * Pronunciation::Acoustic::Features::HOP_MS).to(be > 300)
  end

  it "still scores aspiration when the recording opens with a click" do
    clean = vot_of(room(500) + aspirated)
    clicked = vot_of(click(0.3) + room(500) + aspirated)

    expect(clicked["vot_reliable"]).to(be(true))
    expect(clicked["vot_ms"]).to(be_within(15).of(clean["vot_ms"]))
  end

  it "keeps a syllable that genuinely starts at the first sample" do
    an = analyzed(vowel(320) + room(300))
    low, = Pronunciation::Acoustic::Features.speech_bounds(an)

    expect(low * Pronunciation::Acoustic::Features::HOP_MS).to(be < 60)
  end

  it "refuses to vouch for aspiration when nothing precedes the syllable" do
    expect(vot_of(aspirated)["vot_reliable"]).to(be(false))
  end

  describe "a syllable recorded in a loud room" do
    def alone(level) = room(600, level: level) + vowel(320) + room(400, level: level)

    it "is measured as it would be in a quiet one" do
      quiet = vot_of(alone(0.0005))
      loud = vot_of(alone(0.02))

      expect(loud["duration_ms"]).to(be_within(20).of(quiet["duration_ms"]))
      expect(loud["voiced_ms"]).to(be_within(20).of(quiet["voiced_ms"]))
    end

    it "does not read the room before the syllable as frication" do
      expect(vot_of(alone(0.02))["fric_ms"]).to(be <= 60)
    end

    it "keeps the pre-voicing of a syllable inside what a syllable can carry" do
      expect(vot_of(room(600, level: 0.02) + aspirated)["fric_ms"]).to(
        be <= Pronunciation::Acoustic::Features::MAX_ONSET_MS
      )
    end
  end
end
