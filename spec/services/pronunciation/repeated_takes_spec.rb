# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Consensus do
  it "takes the middle of what was said, not the last of it" do
    rows = [{"vot_ms" => 20.0}, {"vot_ms" => 90.0}, {"vot_ms" => 30.0}]

    expect(described_class.merge(rows)["vot_ms"]).to(eq(30.0))
  end

  it "lets one wild reading be outvoted by two sober ones" do
    rows = [{"tone_range" => 4.0}, {"tone_range" => 18.0}, {"tone_range" => 5.0}]

    expect(described_class.merge(rows)["tone_range"]).to(eq(5.0))
  end

  it "averages a curve point by point" do
    rows = [{"tone_curve" => [0.0, 2.0]}, {"tone_curve" => [1.0, 4.0]}, {"tone_curve" => [2.0, 9.0]}]

    expect(described_class.merge(rows)["tone_curve"]).to(eq([1.0, 4.0]))
  end

  it "averages a cepstral trajectory frame by frame" do
    rows = [{"mfcc" => [[1.0, 1.0]]}, {"mfcc" => [[3.0, 5.0]]}, {"mfcc" => [[2.0, 9.0]]}]

    expect(described_class.merge(rows)["mfcc"]).to(eq([[2.0, 5.0]]))
  end

  it "reads the release from the takes where it was actually found" do
    rows = [
      {"vot_ms" => 140.0, "vot_reliable" => false},
      {"vot_ms" => 62.0, "vot_reliable" => true},
      {"vot_ms" => 68.0, "vot_reliable" => true}
    ]
    merged = described_class.merge(rows)

    expect(merged["vot_ms"]).to(eq(65.0))
    expect(merged["vot_reliable"]).to(be(true))
  end

  it "keeps a flag the majority disagrees with when any take could measure it" do
    rows = [{"vot_reliable" => false}, {"vot_reliable" => false}, {"vot_reliable" => true}]

    expect(described_class.merge(rows)["vot_reliable"]).to(be(true))
  end

  it "records how many readings stand behind the numbers" do
    expect(described_class.merge([{"a" => 1.0}, {"a" => 3.0}])["n_takes"]).to(eq(2))
  end

  it "leaves a single reading exactly as it was" do
    row = {"vot_ms" => 20.0, "clip" => "one.wav"}

    expect(described_class.merge([row])).to(equal(row))
  end

  it "carries text through untouched" do
    rows = [{"clip" => "a.wav"}, {"clip" => "b.wav"}]

    expect(described_class.merge(rows)["clip"]).to(eq("a.wav"))
  end
end

RSpec.describe Pronunciation::Acoustic::Takes do
  def analysis(pattern)
    {energy: pattern}
  end

  def speech(frames) = Array.new(frames, -12.0)
  def quiet(frames) = Array.new(frames, -60.0)

  it "hears one reading as one reading" do
    an = analysis(quiet(10) + speech(30) + quiet(10))

    expect(described_class.wanted(an, 1, 3)).to(eq(1))
  end

  it "hears three readings separated by a pause" do
    gap = quiet((described_class::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(quiet(6) + speech(30) + gap + speech(30) + gap + speech(30) + quiet(6))

    expect(described_class.wanted(an, 1, 3)).to(eq(3))
  end

  it "never splits a sentence into readings" do
    gap = quiet((described_class::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(speech(30) + gap + speech(30) + gap + speech(30))

    expect(described_class.wanted(an, 9, 3)).to(eq(1))
  end

  it "believes the recording over the client when the client asks for more" do
    gap = quiet((described_class::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(speech(30) + gap + speech(30))

    expect(described_class.wanted(an, 2, 3)).to(eq(2))
  end

  it "stays at one reading when the client never asked for more" do
    gap = quiet((described_class::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(speech(30) + gap + speech(30))

    expect(described_class.wanted(an, 2, 1)).to(eq(1))
  end

  it "deals the syllables of each reading back in order" do
    spans = [[0, 1], [2, 3], [10, 11], [12, 13], [20, 21], [22, 23]]

    expect(described_class.group(spans, 2, 3)).to(eq([[[0, 1], [2, 3]], [[10, 11], [12, 13]], [[20, 21], [22, 23]]]))
  end

  it "refuses to deal a hand that does not add up" do
    expect(described_class.group([[0, 1], [2, 3], [4, 5]], 2, 3)).to(be_nil)
  end
end

RSpec.describe Pronunciation::AcousticBackend do
  let(:backend) { described_class.new }

  def analysis(pattern) = {energy: pattern, conf: Array.new(pattern.length, 0.0)}
  def speech(frames) = Array.new(frames, -12.0)
  def quiet(frames) = Array.new(frames, -60.0)

  it "cuts each reading inside its own window, never across the whole recording" do
    gap = quiet((Pronunciation::Acoustic::Takes::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(quiet(6) + speech(40) + gap + speech(40) + gap + speech(40) + quiet(6))
    expected = Array.new(2) { {template: nil} }

    spans = backend.send(:spans_for, an, expected, 3)

    expect(spans.length).to(eq(3))
    expect(spans.map(&:length)).to(all(eq(2)))
    expect(spans.flatten(1).map(&:first)).to(eq(spans.flatten(1).map(&:first).sort))
    expect(spans.first.last.last).to(be < spans.last.first.first)
  end

  it "keeps every reading inside the stretch of speech it came from" do
    gap = quiet((Pronunciation::Acoustic::Takes::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 4)
    an = analysis(quiet(6) + speech(40) + gap + speech(40))
    windows = Pronunciation::Acoustic::Takes.windows(an, 2)
    spans = backend.send(:spans_for, an, Array.new(2) { {template: nil} }, 2)

    spans.each_with_index do |take, index|
      lo, hi = windows[index]
      expect(take.first.first).to(be >= lo)
      expect(take.last.last).to(be <= hi)
    end
  end

  it "keeps a reading whole when the speaker pauses between its syllables" do
    inner = quiet((Pronunciation::Acoustic::Takes::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 6)
    between = quiet((Pronunciation::Acoustic::Takes::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 30)
    word = speech(30) + inner + speech(30)
    an = analysis(quiet(6) + word + between + word + between + word + quiet(6))
    expected = Array.new(2) { {template: nil} }

    spans = backend.send(:spans_for, an, expected, 3)

    expect(spans.length).to(eq(3))
    expect(spans.map(&:length)).to(all(eq(2)))
  end

  it "refuses to call one reading two when nothing was said twice" do
    inner = quiet((Pronunciation::Acoustic::Takes::GAP_MS / Pronunciation::Acoustic::Features::HOP_MS).round + 6)
    an = analysis(quiet(6) + speech(30) + inner + speech(30) + quiet(6))
    expected = Array.new(2) { {template: {"duration_ms" => {"median" => 300.0}}} }

    expect(backend.send(:spans_for, an, expected, 3).length).to(eq(1))
  end
end
