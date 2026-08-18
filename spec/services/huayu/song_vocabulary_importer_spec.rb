# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SongVocabularyImporter do
  let(:path) { Rails.root.join("spec/fixtures/files/song_vocabulary.json") }

  def importer = described_class.new(path:)

  it "imports curated words with their readings and meanings" do
    result = importer.call
    lexeme = Lexeme.find_by(kind: :word, text: "心底")

    expect(result.imported).to(eq(2))
    expect(lexeme.readings).to(include("pinyin" => "xin1 di3", "zhuyin" => "ㄒㄧㄣ ㄉㄧˇ"))
    expect(lexeme.meanings).to(include("en" => "deep down", "ru" => "в глубине души"))
    expect(lexeme.data["pos"]).to(eq("N"))
    expect(lexeme.sources).to(include(described_class::SOURCE))
  end

  it "skips simplified characters, mainland vocabulary and blank rows" do
    result = importer.call

    expect(result.skipped).to(eq(3))
    expect(Lexeme.where(kind: :word, text: %w[说明 信息]).count).to(be_zero)
  end

  it "links every character of an imported word" do
    create(:lexeme, :character, text: "心")
    create(:lexeme, :character, text: "底")

    importer.call

    expect(Lexeme.find_by(kind: :word, text: "心底").components.map(&:text)).to(eq(%w[心 底]))
  end

  it "is idempotent on a second run" do
    importer.call
    before = Lexeme.count

    expect { importer.call }.not_to(change { Lexeme.count }.from(before))
  end
end
