# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::FrequencyImporter do
  let(:chars_path) { Rails.root.join("spec/fixtures/files/freq_chars.csv") }
  let(:words_path) { Rails.root.join("spec/fixtures/files/freq_words.csv") }

  def importer
    described_class.new(chars_path:, words_path:)
  end

  it "ranks existing characters and words by frequency without creating lexemes" do
    tian = create(:lexeme, :character, text: "天")
    di = create(:lexeme, :character, text: "地")
    jintian = create(:lexeme, kind: :word, text: "今天")

    before = Lexeme.count
    result = importer.call

    expect(tian.reload.data["freq_rank"]).to(eq(1))
    expect(di.reload.data["freq_rank"]).to(eq(2))
    expect(jintian.reload.data["freq_rank"]).to(eq(1))
    expect(Lexeme.count).to(eq(before))
    expect(result[:characters][:applied]).to(eq(2))
    expect(result[:words][:applied]).to(eq(1))
  end

  it "counts table entries with no matching lexeme as missing" do
    create(:lexeme, :character, text: "天")

    result = importer.call

    expect(result[:characters][:missing]).to(eq(2))
  end

  it "is idempotent on a second run" do
    create(:lexeme, :character, text: "天")
    importer.call

    result = importer.call

    expect(result[:characters][:applied]).to(eq(0))
  end
end
