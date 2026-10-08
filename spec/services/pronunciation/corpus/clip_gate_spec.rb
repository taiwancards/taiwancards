# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::ClipGate do
  def clean
    {
      "flatness" => 6.0,
      "snr_db" => 60.0,
      "hum_share" => 0.0002,
      "clip_share" => 0.0,
      "pitch_conf" => 0.85
    }
  end

  def row(overrides = {}) = {"_quality" => clean.merge(overrides)}

  it "keeps a recording whose quality was never measured, so old tokens still build" do
    expect(described_class.good?({})).to(be(true))
    expect(described_class.good?("_quality" => {})).to(be(true))
  end

  it "keeps a studio-grade recording" do
    expect(described_class.good?(row)).to(be(true))
    expect(described_class.reasons(row)).to(be_empty)
  end

  it "rejects a noisy recording and names the noise" do
    noisy = row("flatness" => described_class::MAX_FLATNESS + 1)

    expect(described_class.good?(noisy)).to(be(false))
    expect(described_class.reasons(noisy)).to(include("flatness"))
  end

  it "ignores the signal to noise figure, which a tightly trimmed recording cannot report honestly" do
    expect(described_class.good?(row("snr_db" => 4.0))).to(be(true))
  end

  it "rejects rumble and clipping" do
    expect(described_class.good?(row("hum_share" => described_class::MAX_HUM_SHARE * 2))).to(be(false))
    expect(described_class.good?(row("clip_share" => described_class::MAX_CLIP_SHARE * 2))).to(be(false))
  end

  it "rejects a recording whose pitch track cannot be trusted" do
    expect(described_class.good?(row("pitch_conf" => described_class::MIN_PITCH_CONF - 0.1))).to(be(false))
  end

  it "ignores a metric that could not be measured instead of failing the clip" do
    expect(described_class.good?(row("flatness" => nil, "pitch_conf" => nil))).to(be(true))
  end
end
