# frozen_string_literal: true

require "rails_helper"

RSpec.describe Content::Preload do
  it "warms every cache it knows about" do
    result = described_class.new.call

    expect(result.warmed).to(eq(described_class::CACHES.length))
    expect(result.failed).to(eq(0))
  end

  it "leaves the caches populated so a forked worker inherits them" do
    described_class.new.call

    expect(Huayu::BigramFrequency.instance).to(be_available)
    expect(Huayu::TextAnalyzer.vocabulary[:words]).to(be_a(Set))
  end

  it "survives a cache whose reference data is missing" do
    allow(Huayu::StrokeData).to(receive(:has?).and_raise(Errno::ENOENT))

    result = described_class.new.call

    expect(result.failed).to(eq(1))
    expect(result.warmed).to(eq(described_class::CACHES.length - 1))
  end
end
