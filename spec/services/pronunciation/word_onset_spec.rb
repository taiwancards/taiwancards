# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Word-medial onsets" do
  let(:rate) { 48_000 }
  let(:noise) { Random.new(20_260_803) }

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

  def aspirated = breath(8, 0.05) + breath(95, 0.012) + vowel(320)

  def second_syllable(samples, initial: "t")
    an = Pronunciation::Acoustic::Features.analyze(samples, rate)
    spans = Pronunciation::Acoustic::Features.syllable_spans(an, 2) ||
      Pronunciation::Acoustic::Features.forced_spans(an, 2)
    Pronunciation::Acoustic::Features.extract(an, spans[1], initial: initial, utterance_initial: false)
  end

  def alone
    an = Pronunciation::Acoustic::Features.analyze(room(500) + aspirated + room(300), rate)
    span = Pronunciation::Acoustic::Features.speech_bounds(an)
    Pronunciation::Acoustic::Features.extract(an, span, initial: "t", utterance_initial: true)
  end

  it "measures the aspiration of a second syllable in connected speech" do
    f = second_syllable(room(300) + vowel(320) + room(70) + aspirated + room(300))

    expect(f["vot_reliable"]).to(be(true))
    expect(f["vot_ms"]).to(be_within(25).of(alone["vot_ms"]))
  end

  it "measures it just as well when the person pauses between the syllables" do
    f = second_syllable(room(300) + vowel(320) + room(400) + aspirated + room(300))

    expect(f["vot_reliable"]).to(be(true))
    expect(f["vot_ms"]).to(be_within(15).of(alone["vot_ms"]))
  end

  it "refuses to invent a burst when the syllables are slurred together" do
    f = second_syllable(room(300) + vowel(320) + vowel(320, hz: 150.0) + room(300))

    expect(f["vot_reliable"]).to(be(false))
  end

  it "leaves sonorant initials alone" do
    f = second_syllable(room(300) + vowel(320) + room(70) + aspirated + room(300), initial: "l")

    expect(f["vot_ms"]).to(be_nil)
    expect(f["vot_reliable"]).to(be(false))
  end
end
