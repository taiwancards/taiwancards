# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SegmentationVocabulary do
  after { described_class.reset! }

  it "carries the name tier alongside the dictionary list" do
    expect(described_class.words).to(be_superset(described_class.names))
  end

  it "keeps the two lists distinct" do
    expect(described_class.names).not_to(include("一世"))
  end

  it "reads the prior the name file states" do
    expect(described_class.name_prior).to(be > 0)
  end

  it "gives every name a continuation prior the segmenter can use" do
    model = Huayu::BigramFrequency.new
    unseen = described_class.names.reject { |name| model.knows?(name) }

    expect(unseen).to(be_empty)
  end
end
