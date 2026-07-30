# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::Predicate do
  subject(:predicate) { described_class.new }

  it "keeps a sentence carrying a function word that can only attach to a predicate" do
    expect(predicate.missing?("這個想法不對，", words: %w[這個 想法 不對])).to(be(false))
  end

  it "keeps a question, whatever its vocabulary" do
    expect(predicate.missing?("底特律的明天在哪裡？", words: %w[底特律 的 明天 在 哪裡])).to(
      be(false)
    )
  end

  it "drops a heading built from nouns alone" do
    expect(predicate.missing?("土地開挖行為。", words: %w[土地 開挖 行為])).to(be(true))
  end

  it "drops a short list item with no predicate marker" do
    expect(predicate.missing?("廠房及辦公室。", words: %w[廠房 及 辦公室])).to(be(true))
  end

  it "keeps a long sentence on the strength of a single marker" do
    words = %w[羊嶺村 內 各處 都 傳來 炊煙 的 香氣]
    expect(predicate.missing?("羊嶺村內各處都傳來炊煙的香氣。", words:)).to(be(false))
  end

  it "still drops a long sentence when nothing at all points to a predicate" do
    words = %w[羊嶺村 內 各處 傳來 炊煙 的 香氣]
    expect(predicate.missing?("羊嶺村內各處傳來炊煙的香氣。", words:)).to(be(true))
  end

  it "says nothing when the sentence was never segmented" do
    expect(predicate.missing?("土地開挖行為。", words: nil)).to(be(false))
  end
end
