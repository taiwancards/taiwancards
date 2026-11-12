# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::WarmupAnalysis do
  let(:rate) { 22_050 }
  let(:noise) { Random.new(7) }

  def quiet(seconds) = Array.new((rate * seconds).round) { (noise.rand - 0.5) * 20 }

  def voice(seconds, hz)
    Array.new((rate * seconds).round) do |i|
      (1..12).sum { |harmonic| Math.sin(2 * Math::PI * hz * harmonic * i / rate) * 6_000 / harmonic }
    end
  end

  def wav(samples)
    body = samples.map { |value| [value.round.clamp(-32_768, 32_767)].pack("s<") }.join
    header = ["RIFF", 36 + body.bytesize, "WAVE", "fmt ", 16, 1, 1, rate, rate * 2, 2, 16, "data", body.bytesize].pack(
      "a4Va4a4VvvVVvva4V"
    )
    header + body
  end

  def median(values) = values.sort[values.size / 2]

  it "measures the pitch of a voiced recording" do
    [140.0, 220.0].each do |hz|
      result = described_class.new.call(wav(quiet(0.3) + voice(0.8, hz) + quiet(0.3)))

      expect(result[:f0_voiced].size).to(be >= described_class::MIN_VOICED_FRAMES)
      expect(median(result[:f0_voiced])).to(be_within(5).of(hz))
    end
  end

  it "finds nothing to measure in silence" do
    expect(described_class.new.call(wav(quiet(1.0)))).to(be_nil)
  end

  it "finds nothing to measure in a recording too short to carry a voice" do
    expect(described_class.new.call(wav(quiet(0.3) + voice(0.05, 140.0) + quiet(0.3)))).to(be_nil)
  end

  it "answers nil for bytes that are not audio" do
    expect(described_class.new.call("not a recording at all")).to(be_nil)
    expect(described_class.new.call("")).to(be_nil)
  end
end
