# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def dynamic_template
    %w[ma4 ban4 da4 shi4 ma2].filter_map { |key| store.template(key) }.first
  end

  def tone_axis(template, features)
    analyzer.score_axes(features, template, "taiwan").find { |axis| axis["id"] == "tone" }
  end

  def features_for(template, curve, overrides = {})
    {
      "tone_curve" => curve,
      "tone_range" => curve.max - curve.min,
      "tone_slope" => curve.last - curve.first,
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }.merge(overrides).compact
  end

  def reference_of(template)
    probe = features_for(template, Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 0.0))
    tone_axis(template, probe).dig("measured", "reference")
  end

  it "does not raise a wrong contour's score because the register happens to match" do
    template = dynamic_template or skip("no template corpus available")
    wrong = reference_of(template).reverse
    blind = tone_axis(template, features_for(template, wrong))
    matched = tone_axis(template, features_for(template, wrong, "f0_register" => template.dig("f0_register", "median")))

    expect(matched["score"]).to(be <= blind["score"])
  end

  it "still lets a wrong register push a matching contour down" do
    template = dynamic_template or skip("no template corpus available")
    right = reference_of(template)
    centre = template.dig("f0_register", "median")
    on_pitch = tone_axis(template, features_for(template, right, "f0_register" => centre))
    off_pitch = tone_axis(template, features_for(template, right, "f0_register" => centre + 8.0))

    expect(off_pitch["score"]).to(be < on_pitch["score"])
  end

  it "scores a matching contour far above its mirror image" do
    template = dynamic_template or skip("no template corpus available")
    right = reference_of(template)
    good = tone_axis(template, features_for(template, right))
    bad = tone_axis(template, features_for(template, right.reverse))

    expect(good["score"] - bad["score"]).to(be > 20)
  end
end

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def flat_template(tokens)
    template = store.template("ban1")&.deep_dup or return nil
    template["tone"] = 2
    template["tone_contour"] = {
      "center" => Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 0.0),
      "sigma" => Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 1.0),
      "n" => tokens
    }
    template["tone_range"] = (template["tone_range"] || {}).merge("median" => 0.5)
    template
  end

  def reference_used(template)
    features = {
      "tone_curve" => Array.new(Pronunciation::Acoustic::Features::TONE_POINTS, 0.0),
      "tone_range" => 0.5,
      "tone_slope" => 0.0,
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }
    analyzer
      .score_axes(features, template, "taiwan")
      .find { |axis| axis["id"] == "tone" }
      &.dig("measured", "reference")
  end

  it "trusts a flat contour that rests on enough tokens" do
    template = flat_template(24) or skip("no template corpus available")

    expect(reference_used(template).uniq).to(eq([0.0]))
  end

  it "falls back to the canonical curve when the contour rests on too few tokens" do
    template = flat_template(3) or skip("no template corpus available")

    expect(reference_used(template).uniq).not_to(eq([0.0]))
  end
end
