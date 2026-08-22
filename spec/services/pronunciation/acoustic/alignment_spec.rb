# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Alignment do
  SPEECH_DB = -30.0
  BACKGROUND_DB = -85.0
  DIP_DB = -60.0

  def template(voiced_ms)
    {"voiced_ms" => {"median" => voiced_ms}}
  end

  def utterance(runs, total: 70)
    energy = Array.new(total, BACKGROUND_DB)
    mfcc = Array.new(total) { Array.new(13, 0.0) }
    f0 = Array.new(total, 0.0)

    runs.each_with_index do |(from, to), index|
      (from..to).each do |i|
        energy[i] = SPEECH_DB
        f0[i] = 120.0
        mfcc[i] = Array.new(13) { |d| (index + 1) * (d + 1) * 1.0 }
      end

      energy[to + 1] = DIP_DB if to + 1 < total
    end

    {energy:, mfcc:, f0:, n: total, hop: 221, sr: 22_050}
  end

  it "returns the whole audible span for a single syllable" do
    spans = described_class.new.spans(utterance([[10, 40]]), [template(300)])

    expect(spans.length).to(eq(1))
    expect(spans.first[0]).to(be <= 12)
    expect(spans.first[1]).to(be >= 38)
  end

  it "splits two syllables near the dip between them" do
    spans = described_class.new.spans(utterance([[10, 29], [32, 54]]), [template(200), template(230)])

    expect(spans.length).to(eq(2))
    expect(spans[0][1]).to(be_within(4).of(30))
    expect(spans[1][0]).to(eq(spans[0][1] + 1))
  end

  it "hands every syllable a span of its own" do
    runs = [[10, 24], [27, 41], [44, 58]]
    spans = described_class.new.spans(utterance(runs, total: 75), Array.new(3) { template(150) })

    expect(spans.length).to(eq(3))
    expect(spans.each_cons(2).all? { |a, b| b[0] > a[0] && b[1] > a[1] }).to(be(true))
  end

  it "follows the durations the templates expect" do
    long_first = described_class.new.spans(utterance([[10, 54]]), [template(400), template(120)])
    long_second = described_class.new.spans(utterance([[10, 54]]), [template(120), template(400)])

    expect(long_first[0][1] - long_first[0][0]).to(be > long_second[0][1] - long_second[0][0])
  end

  it "declines an utterance too short to hold its syllables" do
    expect(described_class.new.spans(utterance([[10, 14]], total: 20), Array.new(4) { template(200) })).to(be_nil)
  end

  it "declines when a template carries no duration and none can be guessed" do
    expect(described_class.new.spans(utterance([[10, 40]]), [])).to(be_nil)
  end
end
