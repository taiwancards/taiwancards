# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SegmentationBlocks do
  after { Huayu::TextAnalyzer.reset_vocabulary! }

  def word(text) = create(:lexeme, kind: :word, text:)

  it "keeps a listed word out of the segmenter while it keeps its card" do
    word("新社區")
    word("板橋區")

    result = described_class.new(words: %w[新社區]).call

    expect(result.blocked).to(eq(1))
    expect(Lexeme.find_by(text: "新社區").data["no_segment"]).to(be(true))
    expect(Huayu::TextAnalyzer.vocabulary[:words]).to(include("板橋區"))
    expect(Huayu::TextAnalyzer.vocabulary[:words]).not_to(include("新社區"))
  end

  it "blocks a listed word that only the segmentation vocabulary knows" do
    allow(Huayu::SegmentationVocabulary).to(receive(:words).and_return(Set["人欲"]))

    described_class.new(words: %w[人欲]).call

    expect(Huayu::TextAnalyzer.vocabulary[:words]).not_to(include("人欲"))
  end

  it "releases a word that has left the list" do
    blocked = word("新市區")
    described_class.new(words: %w[新市區]).call

    result = described_class.new(words: %w[新社區]).call

    expect(result.released).to(eq(1))
    expect(blocked.reload.data).not_to(have_key("no_segment"))
  end

  it "reads the shipped list when none is given" do
    expect(described_class.words).to(include("日內"))
  end
end
