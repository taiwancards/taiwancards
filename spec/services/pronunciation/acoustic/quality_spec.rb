# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Quality do
  RATE = 22_050

  def harmonic(seconds: 0.6, f0: 140.0, noise: 0.0, amplitude: 0.3, silence: 0.2)
    quiet = Array.new((RATE * silence).round) { (rand - 0.5) * 2 * 1e-4 }
    voiced = Array.new((RATE * seconds).round) do |i|
      t = i / RATE.to_f
      wave = (1..8).sum { |h| Math.sin(2 * Math::PI * f0 * h * t) / h }
      (amplitude * wave) + ((rand - 0.5) * 2 * noise)
    end

    quiet + voiced + quiet
  end

  def measure(samples) = described_class.of(Pronunciation::Acoustic::Features.analyze(samples, RATE))

  it "finds a clean voice flatter in the spectrum than a noisy one" do
    expect(measure(harmonic)["flatness"]).to(be < measure(harmonic(noise: 0.08))["flatness"])
  end

  it "measures the noise floor against real room tone, not against digital silence" do
    room = -> (seconds) { Array.new((RATE * seconds).round) { (rand - 0.5) * 2 * 0.01 } }
    padded = Array.new(RATE / 4, 0.0) + room.call(0.3) + harmonic(silence: 0.0) + room.call(0.3)

    expect(measure(padded)["snr_db"]).to(be_between(5, 45))
  end

  it "charges a hissy recording a lower signal to noise than a quiet one" do
    loud = -> (seconds) { Array.new((RATE * seconds).round) { (rand - 0.5) * 2 * 0.05 } }
    soft = -> (seconds) { Array.new((RATE * seconds).round) { (rand - 0.5) * 2 * 0.0005 } }

    hissy = loud.call(0.3) + harmonic(silence: 0.0) + loud.call(0.3)
    clean = soft.call(0.3) + harmonic(silence: 0.0) + soft.call(0.3)

    expect(measure(hissy)["snr_db"]).to(be < measure(clean)["snr_db"])
  end

  it "counts clipping" do
    clipped = harmonic(amplitude: 2.0).map { |v| v.clamp(-1.0, 1.0) }
    expect(measure(clipped)["clip_share"]).to(be > 0.01)
    expect(measure(harmonic)["clip_share"]).to(eq(0.0))
  end

  it "says nothing about a recording with no voicing at all" do
    expect(measure(Array.new(RATE / 2) { (rand - 0.5) * 2e-4 })).to(eq({}))
  end
end
