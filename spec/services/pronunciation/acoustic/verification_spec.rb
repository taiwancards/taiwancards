# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Verification do
  describe ".code_for" do
    it "accepts a syllable that outranks most of the field" do
      expect(described_class.code_for(0.1)).to(eq("read.ok"))
    end

    it "doubts a syllable adrift in the middle of the field" do
      expect(described_class.code_for(described_class::DOUBTFUL_PERCENTILE)).to(eq("read.doubtful"))
    end

    it "calls it a mismatch once the field mostly beats it" do
      expect(described_class.code_for(described_class::MISMATCH_PERCENTILE)).to(eq("read.mismatch"))
    end
  end

  describe ".check" do
    let(:rows) { Array.new(3) { |i| {key: "ni3", norm: "taiwan", index: i, features: {}, template: {}} } }

    it "says nothing about a single syllable" do
      expect(described_class.check(rows.first(1))).to(be_nil)
    end

    it "says nothing when every syllable was absent" do
      expect(described_class.check(rows.map { |row| row.merge(absent: true) })).to(be_nil)
    end

    it "settles without consulting the field when the reading already scores well" do
      result = described_class.check(rows, overall: described_class::SETTLED_SCORE)

      expect(result["code"]).to(eq("read.ok"))
      expect(result["confidence"]).to(eq(1.0))
      expect(result["syllables"]).to(be_empty)
    end

    it "consults the field when the reading scores poorly" do
      result = described_class.check(rows, overall: described_class::SETTLED_SCORE - 1)

      expect(result.nil? || result["syllables"].empty?).to(be(true))
    end
  end

  describe ".build_pool" do
    it "spreads evenly over the inventory it is given" do
      store = instance_double(Pronunciation::TemplateStore, index: {"keys" => (1..500).to_h { |i| ["k#{i}", {}] }})

      pool = described_class.build_pool(store)

      expect(pool.length).to(eq(described_class::POOL_SIZE))
      expect(pool.uniq.length).to(eq(pool.length))
    end

    it "declines an inventory too small to spread over" do
      store = instance_double(Pronunciation::TemplateStore, index: {"keys" => {"a1" => {}}})

      expect(described_class.build_pool(store)).to(be_empty)
    end
  end
end
