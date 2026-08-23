# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Features do
  describe ".formants_reliable?" do
    it "rejects a vector whose second formant has merged into the third" do
      expect(described_class.formants_reliable?(0.65, 1.0)).to(be(false))
    end

    it "rejects a vector whose first formant has merged into the second" do
      expect(described_class.formants_reliable?(0.72, 0.85)).to(be(false))
    end

    it "rejects a vector measured without a usable third formant" do
      expect(described_class.formants_reliable?(nil, nil)).to(be(false))
    end

    it "accepts an ordinary open vowel" do
      expect(described_class.formants_reliable?(0.35, 0.6)).to(be(true))
    end

    it "accepts an ordinary close front vowel" do
      expect(described_class.formants_reliable?(0.1, 0.76)).to(be(true))
    end
  end
end

RSpec.describe Pronunciation::Acoustic::Analyzer do
  let(:store) { Pronunciation::TemplateStore.instance }
  let(:analyzer) { described_class.new(store) }

  def features_for(template, overrides = {})
    {
      "f1_over_f0" => template.dig("f1_over_f0", "median"),
      "f2_over_f1" => template.dig("f2_over_f1", "median"),
      "f2_onset_ratio" => template.dig("f2_onset_ratio", "median"),
      "f1_onset_over_f0" => template.dig("f1_onset_over_f0", "median"),
      "duration_ms" => template.dig("duration_ms", "median"),
      "voiced_ms" => template.dig("voiced_ms", "median")
    }.merge(overrides)
  end

  def axis_ids(template, overrides)
    analyzer.score_axes(features_for(template, overrides), template, "taiwan").map { |axis| axis["id"] }
  end

  it "scores the vowel when the formants are trustworthy" do
    template = store.template("ban1") or skip("no template corpus available")

    expect(axis_ids(template, "formants_reliable" => true)).to(include("vowel"))
  end

  it "withholds the vowel rather than guessing when the formants merged" do
    template = store.template("ban1") or skip("no template corpus available")

    expect(axis_ids(template, "formants_reliable" => false)).not_to(include("vowel"))
  end

  it "withholds the vowel when no formant ratio was measured at all" do
    template = store.template("ban1") or skip("no template corpus available")

    expect(axis_ids(template, "f1_over_f0" => nil, "f2_over_f1" => nil)).not_to(include("vowel"))
  end

  it "still reports the tone when the formants are untrustworthy" do
    template = store.template("ban1") or skip("no template corpus available")
    overrides = {
      "formants_reliable" => false,
      "tone_curve" => template.dig("tone_contour", "center"),
      "tone_range" => template.dig("tone_range", "median"),
      "tone_slope" => template.dig("tone_slope", "median")
    }

    expect(axis_ids(template, overrides)).to(include("tone"))
  end
end
