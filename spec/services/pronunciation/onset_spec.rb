# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Onset do
  let(:rate) { 22_050 }
  let(:noise) { Random.new(20_260_725) }

  def silence(ms) = Array.new((rate * ms / 1000.0).round) { noise.rand * 1e-4 }

  def friction(ms, level)
    Array.new((rate * ms / 1000.0).round) do |i|
      ((noise.rand * 2) - 1) * level * Math.cos(2 * Math::PI * 4200 * i / rate)
    end
  end

  def voicing(ms, hz: 150.0, level: 0.3)
    Array.new((rate * ms / 1000.0).round) do |i|
      t = i.to_f / rate
      level * (Math.sin(2 * Math::PI * hz * t) + (0.5 * Math.sin(4 * Math::PI * hz * t)))
    end
  end

  def measure(samples)
    described_class.measure(samples, rate, 0, samples.length, back_ms: 300.0)
  end

  it "puts the release where the noise starts and the onset where voicing starts" do
    samples = silence(200) + friction(6, 0.35) + friction(60, 0.06) + voicing(300)

    result = measure(samples)

    expect(result[:vot_ms]).to(be_within(12).of(66))
  end

  it "separates an unaspirated release from an aspirated one" do
    short = measure(silence(200) + friction(6, 0.35) + silence(14) + voicing(300))
    long = measure(silence(200) + friction(6, 0.35) + friction(90, 0.06) + voicing(300))

    expect(short[:vot_ms]).to(be < 40)
    expect(long[:vot_ms]).to(be > 70)
  end

  it "reports no release when voicing starts straight away" do
    result = measure(silence(200) + voicing(300))

    expect(result[:burst_ms]).to(be_nil)
    expect(result[:vot_ms]).to(be_nil)
  end

  it "is unmoved by a quieter recording" do
    samples = silence(200) + friction(6, 0.35) + friction(60, 0.06) + voicing(300)
    quiet = samples.map { |v| v * 0.1 }

    expect(measure(quiet)[:vot_ms]).to(be_within(6).of(measure(samples)[:vot_ms]))
  end

  describe "a recording trimmed flush to the onset" do
    def from_edge(samples)
      described_class.measure(samples, rate, 0, samples.length, from_edge: true)
    end

    it "treats the first sample as the release" do
      result = from_edge(friction(6, 0.35) + friction(90, 0.06) + voicing(300))

      expect(result[:vot_ms]).to(be_within(15).of(96))
    end

    it "still tells an unaspirated stop from an aspirated one" do
      unaspirated = from_edge(voicing(300) + silence(120))
      aspirated = from_edge(friction(6, 0.35) + friction(90, 0.06) + voicing(300) + silence(120))

      expect(unaspirated[:vot_ms]).to(be < 20)
      expect(aspirated[:vot_ms]).to(be > 70)
    end

    it "accepts a lag of nothing at all, which silence would not" do
      expect(described_class.plausible?(0.5, from_edge: true)).to(be(true))
      expect(described_class.plausible?(0.5)).to(be(false))
    end

    it "does not mistake ongoing aspiration for the start of voicing" do
      samples = friction(120, 0.12) + voicing(300) + silence(120)

      expect(from_edge(samples)[:vot_ms]).to(be > 80)
    end
  end

  it "calls an impossible span implausible" do
    expect(described_class.plausible?(nil)).to(be(false))
    expect(described_class.plausible?(1.0)).to(be(false))
    expect(described_class.plausible?(60.0)).to(be(true))
  end
end
