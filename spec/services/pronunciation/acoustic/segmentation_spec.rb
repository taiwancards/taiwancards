# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Features do
  QUIET = -95.0
  LOUD = -30.0
  MURMUR = -45.0

  def analysis(energy)
    {energy:, n: energy.length}
  end

  def two_peaks(gap: QUIET)
    Array.new(6, QUIET) + Array.new(14, LOUD) + Array.new(10, gap) + Array.new(14, LOUD) + Array.new(6, QUIET)
  end

  it "splits a two-peak utterance into two contiguous spans" do
    spans = described_class.syllable_spans(analysis(two_peaks), 2)

    expect(spans.length).to(eq(2))
    expect(spans[0][1]).to(eq(spans[1][0]))
    expect(spans[0][0]).to(be < spans[0][1])
    expect(spans[1][0]).to(be < spans[1][1])
  end

  it "keeps a low sonorant tail with the syllable it belongs to" do
    energy = Array.new(6, QUIET) +
      Array.new(14, LOUD) +
      Array.new(12, MURMUR) +
      Array.new(14, LOUD) +
      Array.new(6, QUIET)
    murmur_last = 6 + 14 + 12 - 1

    spans = described_class.syllable_spans(analysis(energy), 2)

    expect(spans.length).to(eq(2))
    expect(spans[0][1]).to(be >= murmur_last - 2)
  end

  it "cannot find peaks in a short fused utterance but forced spans still divide it" do
    fused = Array.new(6, QUIET) + Array.new(12, LOUD) + Array.new(6, QUIET)

    expect(described_class.syllable_spans(analysis(fused), 2)).to(be_nil)

    spans = described_class.forced_spans(analysis(fused), 2)
    expect(spans.length).to(eq(2))
    expect(spans[0][1]).to(eq(spans[1][0]))
    expect(spans[1][1] - spans[0][0]).to(be >= 10)
  end

  it "refuses forced spans when there is not enough speech to divide" do
    tiny = Array.new(4, QUIET) + Array.new(4, LOUD) + Array.new(4, QUIET)

    expect(described_class.forced_spans(analysis(tiny), 4)).to(be_nil)
  end
end
