# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::ContextNorms do
  it "names a cell by the syllable's tone and the tones on either side" do
    expect(described_class.cell(2, 4, 1)).to(eq("2,4,1"))
  end

  it "reads the edge of an utterance as tone zero" do
    expect(described_class.spot_of(0, 3)).to(eq("first"))
    expect(described_class.spot_of(3, 0)).to(eq("last"))
    expect(described_class.spot_of(3, 3)).to(eq("middle"))
    expect(described_class.spot_of(0, 0)).to(eq("alone"))
  end

  it "never stretches a syllable read on its own" do
    expect(described_class.stretch("alone")).to(be_nil)
  end

  it "lengthens the last syllable of a phrase and shortens the middle" do
    last = described_class.stretch("last")
    middle = described_class.stretch("middle")
    skip("no context norms available") if last.nil? || middle.nil?

    expect(last).to(be > middle)
  end

  it "bends the reference where a cell exists and leaves it alone where none does" do
    centre = Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 0.0)
    known = described_class.curves.keys.first
    skip("no context norms available") if known.nil?

    tone, before, following = known.split(",").map(&:to_i)

    expect(described_class.place(centre, tone, before, following)).not_to(eq(centre))
    expect(described_class.place(centre, tone, 9, 9)).to(eq(centre))
  end

  it "leaves a contour alone when the tone is unknown" do
    centre = [1.0, 2.0]

    expect(described_class.place(centre, 0, 1, 1)).to(eq(centre))
  end
end
