# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def coda_axis(nasal_ratio)
    template = store.template("ban1") or skip("no template corpus available")
    features = {
      "nasal_ratio_tail" => nasal_ratio,
      "f1_ratio" => template.dig("f1_ratio", "median"),
      "f2_ratio" => template.dig("f2_ratio", "median"),
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }
    analyzer.score_axes(features, template, "taiwan").find { |axis| axis["id"] == "coda" }
  end

  it "reports a dropped nasal as a weak coda" do
    template = store.template("ban1") or skip("no template corpus available")
    axis = coda_axis(template.dig("nasal_ratio_tail", "median") * 0.2)

    expect(axis["code"]).to(eq("coda.weak"))
  end

  it "never claims which nasal it heard, because it cannot tell" do
    template = store.template("ban1") or skip("no template corpus available")
    codes = [0.05, 0.3, 0.6, 0.9, 1.0].map { |value| coda_axis(value)&.fetch("code", nil) }

    expect(codes.compact).to(all(be_in(%w[coda.ok coda.weak coda.heavy])))
  end
end
