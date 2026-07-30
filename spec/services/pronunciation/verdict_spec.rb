# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Verdict do
  let(:store) { instance_double(Pronunciation::TemplateStore, thresholds: thresholds) }
  let(:thresholds) { {"thresholds" => {}} }

  subject(:verdict) { described_class.new(store:) }

  it "separates four levels rather than three" do
    expect(verdict.level("overall", 95)).to(eq("green"))
    expect(verdict.level("overall", 70)).to(eq("amber"))
    expect(verdict.level("overall", 55)).to(eq("red"))
    expect(verdict.level("overall", 20)).to(eq("dark"))
  end

  it "reports gray when nothing was measured" do
    expect(verdict.level("initial", nil)).to(eq("gray"))
  end

  it "puts a floor under a degenerate red bound" do
    allow(store).to(
      receive(:thresholds).and_return(
        {"thresholds" => {"initial" => {"green" => 92, "red" => 0, "neg_median" => 47}}}
      )
    )

    expect(verdict.bounds("initial")["red"]).to(be >= 40)
    expect(verdict.level("initial", 35)).to(eq("red"))
  end

  it "keeps the dark bound strictly below the red bound" do
    described_class::CELLS.each do |cell|
      bounds = verdict.bounds(cell)
      expect(bounds["dark"]).to(be < bounds["red"])
    end
  end

  it "withholds a verdict only when another syllable fits better and the score is low" do
    expect(verdict.rejected?(40, "kao1", "gao1")).to(be(true))
    expect(verdict.rejected?(80, "kao1", "gao1")).to(be(false))
    expect(verdict.rejected?(40, "gao1", "gao1")).to(be(false))
  end

  it "ranks the worst part by shortfall against its own threshold, not by raw score" do
    parts = [
      {"id" => "final", "score" => 90},
      {"id" => "tone", "score" => 85}
    ]

    expect(verdict.worst_part(parts)).to(eq("final"))
  end
end
