# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Weights do
  INVENTORY = {
    "ma" => [1, 2, 3, 4],
    "mo" => [2],
    "mi" => [3],
    "mai" => [3],
    "man" => [4],
    "mang" => [2],
    "mei" => [2],
    "gao" => [1, 3],
    "kao" => [3],
    "gan" => [1],
    "sen" => [1],
    "shen" => [1],
    "seng" => [1]
  }.freeze

  before do
    @dir = Dir.mktmpdir
    keys = INVENTORY
      .flat_map { |syllable, tones|
        tones.map { |tone| ["#{syllable}#{tone}", {"syllable" => syllable, "tone" => tone, "zhuyin" => ""}] }
      }
      .to_h
    File.write(File.join(@dir, "inventory.json"), JSON.dump({"keys" => keys}))
    Pronunciation::Acoustic::Syllables.load!(File.join(@dir, "inventory.json"))
    described_class.reset!
  end

  after do
    FileUtils.remove_entry(@dir)
    Pronunciation::Acoustic::Syllables.load!
    described_class.reset!
  end

  def share_of(syllable, tone, part, parts: %w[initial final tone])
    described_class.shares(described_class.for_syllable(syllable, tone, parts))[part]
  end

  it "gives a sonorant initial with no minimal pair less weight than a contrastive one" do
    expect(share_of("ma", 1, "initial")).to(be < share_of("gao", 1, "initial"))
  end

  it "counts the aspiration partner as an initial rival and finds none for a sonorant" do
    expect(described_class.count_rivals("gao", 1)["initial"]).to(eq(1))
    expect(described_class.count_rivals("ma", 1)["initial"]).to(eq(0))
  end

  it "counts every attested rime after the same initial as a rival for the final" do
    expect(described_class.count_rivals("ma", 1)["final"]).to(eq(6))
  end

  it "drops the tone rivals for a syllable attested in one tone only" do
    expect(described_class.count_rivals("sen", 1)["tone"]).to(eq(0))
    expect(described_class.count_rivals("ma", 1)["tone"]).to(eq(3))
  end

  it "normalises shares to one" do
    weights = described_class.for_syllable("gao", 1, %w[initial final tone])
    expect(described_class.shares(weights).values.sum).to(be_within(0.01).of(1.0))
  end

  it "only weights the parts that were actually measured" do
    weights = described_class.for_syllable("gao", 1, %w[final tone])
    expect(weights.keys).to(contain_exactly("final", "tone"))
  end

  it "raises the weight when the templates separate that part acoustically" do
    flat = described_class.for_syllable("ma", 1, ["initial"])["initial"]
    separated = described_class.for_syllable("ma", 1, ["initial"], profile: {"vot_ms" => {"d" => 2.5}})["initial"]

    expect(separated).to(be > flat)
  end

  it "never lets a part fall to zero weight while it is being measured" do
    weights = described_class.for_syllable("ma", 1, %w[initial medial final tone])
    expect(weights.values).to(all(be > 0))
  end
end
