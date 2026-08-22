# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Features do
  BACKDROP = -95.0
  SPEAKING = -30.0
  PAUSE = -78.0

  def energies(energy) = {energy:, n: energy.length}

  def phrase(pause_frames)
    Array.new(8, BACKDROP) +
      Array.new(16, SPEAKING) +
      Array.new(pause_frames, PAUSE) +
      Array.new(16, SPEAKING) +
      Array.new(8, BACKDROP)
  end

  describe ".utterance_bounds" do
    it "delegates to the single-syllable bounds when only one is expected" do
      energy = phrase(30)

      expect(described_class.utterance_bounds(energies(energy), 1))
        .to(eq(described_class.speech_bounds(energies(energy))))
    end

    it "spans a pause long enough to end a single walk outwards" do
      energy = phrase(30)
      low, high = described_class.utterance_bounds(energies(energy), 2)

      expect(low).to(be <= 9)
      expect(high).to(be >= energy.length - 10)
    end

    it "covers far more of a paused phrase than the single-syllable bounds do" do
      energy = phrase(30)
      single = described_class.speech_bounds(energies(energy))
      both = described_class.utterance_bounds(energies(energy), 2)

      expect(both[1] - both[0]).to(be > single[1] - single[0])
    end

    it "leaves an unbroken phrase where it was" do
      energy = phrase(2)

      expect(described_class.utterance_bounds(energies(energy), 2))
        .to(eq(described_class.speech_bounds(energies(energy))))
    end
  end
end
