# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Register do
  it "places each syllable against the pitch centre of the utterance" do
    placed = described_class.from_utterance([200.0, 100.0, 100.0], [0.0, 0.0, 0.0])

    expect(placed[0]).to(be_within(0.01).of(12.0))
    expect(placed[1]).to(be_within(0.01).of(0.0))
  end

  it "lifts the whole utterance by what its own tones are expected to sit at" do
    flat = described_class.from_utterance([100.0, 100.0], [2.0, 4.0])

    expect(flat).to(all(be_within(0.01).of(3.0)))
  end

  it "says nothing about a single syllable, which carries no range of its own" do
    expect(described_class.from_utterance([180.0], [0.0])).to(be_empty)
  end

  it "ignores frames with no pitch at all" do
    placed = described_class.from_utterance([200.0, 0.0, 100.0, 100.0], [0.0, 0.0, 0.0, 0.0])

    expect(placed[1]).to(be_nil)
    expect(placed[0]).to(be_within(0.01).of(12.0))
  end
end
