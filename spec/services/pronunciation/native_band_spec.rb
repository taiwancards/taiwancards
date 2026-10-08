# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def banded_template
    %w[ma4 ma2 ma1 ba4 de5 ban1 da4 na4]
      .filter_map { |key| store.template(key, "taiwan_word") }
      .find { |template| template.dig("tone_contour", "low").present? && template["mark_mid"].present? }
  end

  def tone_axis(template, curve)
    features = {
      "tone_curve" => curve,
      "tone_range" => curve.max - curve.min,
      "tone_slope" => curve.last - curve.first,
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }
    analyzer.score_axes(features, template, "taiwan_word").find { |axis| axis["id"] == "tone" }
  end

  it "asks nothing of a contour that lands on the reference" do
    template = banded_template or skip("no banded template available")
    axis = tone_axis(template, template.dig("tone_contour", "center"))

    expect(axis["z"]).to(be < 1.0)
    expect(axis["code"]).to(eq("tone.ok"))
  end

  it "charges a contour more the further it drifts from the reference" do
    template = banded_template or skip("no banded template available")
    center = template.dig("tone_contour", "center")
    near = tone_axis(template, center.map { |v| v * 0.8 })
    far = tone_axis(template, center.map { |v| v * 0.2 })

    expect(far["z"]).to(be > near["z"])
  end

  it "scores a matching contour far above a zig-zag" do
    template = banded_template or skip("no banded template available")
    center = template.dig("tone_contour", "center")
    broken = center.map.with_index { |v, i| i.even? ? v + 6.0 : v - 6.0 }

    expect(tone_axis(template, center)["score"] - tone_axis(template, broken)["score"]).to(be > 40)
  end

  it "publishes a band so the learner can see what is being asked" do
    template = banded_template or skip("no banded template available")
    band = tone_axis(template, template.dig("tone_contour", "center")).dig("measured", "band")

    expect(band.length).to(eq(Pronunciation::Acoustic::Features::TONE_POINTS))
    expect(band).to(all(satisfy { |low, high| high > low }))
  end

  it "keeps the observed band narrow where speakers agree and wide where they do not" do
    template = banded_template or skip("no banded template available")
    tc = template["tone_contour"]
    widths = tc["low"].each_index.map { |i| tc["high"][i] - tc["low"][i] }
    middle = widths[widths.length / 2]

    expect([widths.first, widths.last].max).to(be > middle)
  end
end

RSpec.describe Pronunciation::Acoustic::Templates do
  it "drops a contour whose octave jumped before measuring the band" do
    sane = Array.new(16) { |i| i * 0.1 }
    broken = Array.new(16) { |i| i.even? ? 0.0 : 30.0 }

    expect(described_class.sane_curve?(sane)).to(be(true))
    expect(described_class.sane_curve?(broken)).to(be(false))
  end

  it "keeps a floor under the band so a thin key cannot demand perfection" do
    flat = Array.new(8) { Array.new(16, 1.0) }
    band = described_class.observed_band(flat)

    expect(band["high"].first - band["low"].first).to(be_within(0.01).of(0.8))
  end
end
