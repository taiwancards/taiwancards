# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::StyleFactor do
  subject(:factor) { described_class.new(io: nil) }

  before { allow(factor).to(receive(:factors).and_return(factors)) }

  let(:factors) { {"median" => 2.0, "per_field" => {"vot_ms" => 4.0}} }

  it "divides each field by its own style factor" do
    expect(factor.correct("vot_ms" => 8.0)["vot_ms"]).to(eq(2.0))
  end

  it "falls back to the median for a field with no factor of its own" do
    expect(factor.correct("tone_range" => 8.0)["tone_range"]).to(eq(4.0))
  end

  it "falls back to the median when a field's factor came out as zero" do
    factors["per_field"]["voiced_ratio"] = 0.0

    expect(factor.correct("voiced_ratio" => 8.0)["voiced_ratio"]).to(eq(4.0))
  end

  it "leaves the model alone when nothing was measured" do
    allow(factor).to(receive(:factors).and_return({}))

    expect(factor.correct("vot_ms" => 8.0)).to(eq("vot_ms" => 8.0))
  end

  it "scales the tone contour by the tone range factor" do
    factors["per_field"]["tone_range"] = 2.0

    expect(factor.correct("tone_contour" => [4.0, 2.0])["tone_contour"]).to(eq([2.0, 1.0]))
  end
end
