# frozen_string_literal: true

require "rails_helper"

RSpec.describe "song vocabulary data" do
  let(:entries) { JSON.parse(Rails.root.join("data/huayu/song_vocabulary.json").read) }
  let(:priors) { JSON.parse(Rails.root.join("data/huayu/segmentation_priors.json").read)["continuation"] }

  it "carries a reading, a part of speech and both glosses for every word" do
    incomplete = entries.reject { |entry|
      %w[text pinyin zhuyin pos en ru].all? { |field| entry[field].to_s.present? }
    }

    expect(incomplete).to(be_empty)
  end

  it "holds only traditional characters used in Taiwan" do
    offenders = entries.filter_map { |entry|
      entry["text"] if Huayu::TraditionalOnly.simplified(entry["text"]).any?
    }

    expect(offenders).to(be_empty)
  end

  it "gives the segmenter a prior for every word it ships" do
    expect(entries.map { |entry| entry["text"] } - priors.keys).to(be_empty)
  end

  it "keeps the priors free of words the vocabulary no longer carries" do
    expect(priors.keys - entries.map { |entry| entry["text"] }).to(be_empty)
  end
end
