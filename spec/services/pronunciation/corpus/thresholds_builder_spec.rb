# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pronunciation::Corpus::ThresholdsBuilder do
  let(:builder) { described_class.allocate }

  def auc(good, bad) = builder.send(:auc, Hash.new(0).merge(good), Hash.new(0).merge(bad))

  it "reads one when every right rendition outscores every wrong one" do
    expect(auc({90 => 10}, {40 => 10})).to(eq(1.0))
  end

  it "reads a half when the two sides land on the same score" do
    expect(auc({70 => 10}, {70 => 10})).to(eq(0.5))
  end

  it "counts a tie as half a win" do
    expect(auc({80 => 2}, {80 => 1, 10 => 1})).to(eq(0.75))
  end

  it "reads zero when the wrong renditions score higher throughout" do
    expect(auc({20 => 5}, {95 => 5})).to(eq(0.0))
  end

  it "has nothing to report when one side is empty" do
    expect(auc({50 => 4}, {})).to(be_nil)
  end
end
