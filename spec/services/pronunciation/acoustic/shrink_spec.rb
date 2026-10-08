# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Acoustic::Shrink do
  def template(tone:, median:, mad:, n:)
    {
      "tone" => tone,
      "mark_mid" => {"median" => median, "mad" => mad, "sigma_within" => mad, "sigma_between" => 0.5, "n" => n}
    }
  end

  def crowd(tone: 4, mad: 1.0, n: 12, size: described_class::MIN_KEYS)
    Array.new(size) { |i| template(tone: tone, median: (i % 7) - 3.0, mad: mad, n: n) }
  end

  it "pulls a thinly attested median toward the prior and leaves a well attested one alone" do
    thin = template(tone: 4, median: 9.0, mad: 4.0, n: 3)
    solid = template(tone: 4, median: 9.0, mad: 0.4, n: 60)
    described_class.apply!(crowd + [thin, solid])

    expect(thin["mark_mid"]["median"]).to(be < solid["mark_mid"]["median"])
    expect(solid["mark_mid"]["median"]).to(be_within(0.5).of(9.0))
    expect(thin["mark_mid"]["median_own"]).to(eq(9.0))
  end

  it "weighs a key's own tokens by how many of them there are" do
    thin = template(tone: 4, median: 9.0, mad: 4.0, n: 3)
    solid = template(tone: 4, median: 9.0, mad: 0.4, n: 60)
    described_class.apply!(crowd + [thin, solid])

    expect(thin["mark_mid"]["weight"]).to(be < 0.8)
    expect(solid["mark_mid"]["weight"]).to(be > 0.99)
  end

  it "raises a spread that is too tight to believe toward the pooled one" do
    tight = template(tone: 4, median: 0.0, mad: 0.05, n: 3)
    described_class.apply!(crowd(mad: 2.0) + [tight])

    expect(tight["mark_mid"]["sigma_within"]).to(be > 1.0)
    expect(tight["mark_mid"]["sigma_within_own"]).to(eq(0.05))
  end

  it "lowers a spread that is too wide to believe toward the pooled one" do
    wide = template(tone: 4, median: 0.0, mad: 9.0, n: 3)
    described_class.apply!(crowd(mad: 1.0) + [wide])

    expect(wide["mark_mid"]["sigma_within"]).to(be < 4.0)
    expect(wide["mark_mid"]["sigma"]).to(be > wide["mark_mid"]["sigma_within"])
  end

  it "does not compound when applied twice" do
    thin = template(tone: 4, median: 9.0, mad: 4.0, n: 3)
    group = crowd + [thin]
    described_class.apply!(group)
    once = thin["mark_mid"].slice("median", "sigma_within")
    described_class.apply!(group)

    expect(thin["mark_mid"]["median"]).to(be_within(1e-9).of(once["median"]))
    expect(thin["mark_mid"]["sigma_within"]).to(be_within(1e-9).of(once["sigma_within"]))
  end

  it "leaves a tone with too few syllables alone" do
    lonely = template(tone: 5, median: 9.0, mad: 4.0, n: 3)
    described_class.apply!(crowd + [lonely])

    expect(lonely["mark_mid"]["median"]).to(eq(9.0))
    expect(lonely["mark_mid"]).not_to(include("weight"))
  end
end
