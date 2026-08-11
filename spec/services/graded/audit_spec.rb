# frozen_string_literal: true

require "rails_helper"

RSpec.describe Graded::Audit do
  let(:reports) { described_class.new.call }

  it "keeps every text inside its tier, with a gloss for anything above it" do
    expect(reports.reject(&:clean?).map(&:to_s)).to(eq([]))
  end

  it "covers at least ninety per cent of every text with the tier vocabulary" do
    thin = reports.select { |report| report.rate < described_class::FLOOR }

    expect(thin.map(&:to_s)).to(eq([]))
  end

  it "publishes texts for every tier that has a file" do
    expect(Graded::Library.tiers).to(be_present)
    Graded::Library.tiers.each do |tier|
      expect(Graded::Library.texts(tier).size).to(be >= 5)
    end
  end

  it "builds tiers as prefixes of one ranked inventory" do
    chars = Graded::Levels.all.select(&:chars?)

    chars.each_cons(2) do |smaller, larger|
      expect(larger.items.first(smaller.size)).to(eq(smaller.items))
    end
  end
end
