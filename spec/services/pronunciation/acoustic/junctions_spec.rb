# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Junctions do
  LOUD_DB = -30.0
  SILENT_DB = -80.0

  def analysis(conf:, f0:, energy:)
    {conf:, f0:, energy:, n: conf.length}
  end

  def flat(length, voiced_from, voiced_to, hz: 120.0, gap_db: LOUD_DB)
    conf = Array.new(length, 0.0)
    f0 = Array.new(length, 0.0)
    energy = Array.new(length, gap_db)
    (voiced_from..voiced_to).each do |i|
      conf[i] = 0.9
      f0[i] = hz
      energy[i] = LOUD_DB
    end

    [conf, f0, energy]
  end

  def joined(left_to, right_from, length: 40, right_hz: 120.0, dip_db: LOUD_DB)
    conf = Array.new(length, 0.0)
    f0 = Array.new(length, 0.0)
    energy = Array.new(length, dip_db)
    (5..left_to).each { |i|
      conf[i] = 0.9
      f0[i] = 120.0
      energy[i] = LOUD_DB
    }
    (right_from..(length - 5)).each { |i|
      conf[i] = 0.9
      f0[i] = right_hz
      energy[i] = LOUD_DB
    }
    analysis(conf:, f0:, energy:)
  end

  describe ".cell" do
    it "calls a stop initial a stop" do
      expect(described_class.cell("ba1")).to(eq("stop"))
    end

    it "calls an affricate an affricate" do
      expect(described_class.cell("zhong1")).to(eq("affricate"))
    end

    it "calls a nasal initial a nasal" do
      expect(described_class.cell("ma1")).to(eq("nasal"))
    end

    it "calls a syllable without an initial a vowel" do
      expect(described_class.cell("an1")).to(eq("vowel"))
    end

    it "falls back when the key cannot be parsed" do
      expect(described_class.cell("???")).to(eq(described_class::DEFAULT_CELL))
    end
  end

  describe ".measure" do
    it "reports no gap when voicing runs straight through" do
      junction = described_class.measure(joined(19, 20), [[0, 19], [20, 39]]).first

      expect(junction["gap_ms"]).to(eq(0.0))
    end

    it "measures the silence between two voiced runs" do
      junction = described_class.measure(joined(14, 25), [[0, 19], [20, 39]]).first

      expect(junction["gap_ms"]).to(eq((25 - 14 - 1) * Pronunciation::Acoustic::Features::HOP_MS))
    end

    it "measures the pitch step across the junction in semitones" do
      junction = described_class.measure(joined(19, 20, right_hz: 240.0), [[0, 19], [20, 39]]).first

      expect(junction["f0_jump"]).to(be_within(0.01).of(12.0))
    end

    it "measures how far the energy falls between the runs" do
      junction = described_class.measure(joined(14, 25, dip_db: SILENT_DB), [[0, 19], [20, 39]]).first

      expect(junction["dip_db"]).to(be_within(0.01).of(LOUD_DB - SILENT_DB))
    end

    it "reports nothing for a span with no voicing at all" do
      conf, f0, energy = flat(40, 5, 14)
      spans = [[0, 19], [20, 39]]

      expect(described_class.measure(analysis(conf:, f0:, energy:), spans)).to(eq([nil]))
    end
  end

  describe ".strain" do
    it "is zero at or below the usual spread" do
      expect(described_class.strain(50.0, {"p75" => 80.0, "p90" => 140.0}, 40.0)).to(eq(0.0))
    end

    it "grows once the value passes the usual spread" do
      expect(described_class.strain(140.0, {"p75" => 80.0, "p90" => 140.0}, 40.0)).to(be_within(0.01).of(1.0))
    end

    it "uses the floor when the reference has no spread" do
      expect(described_class.strain(120.0, {"p75" => 80.0, "p90" => 80.0}, 40.0)).to(be_within(0.01).of(1.0))
    end
  end
end
