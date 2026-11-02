# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SentenceMeaningFiller do
  let(:source) { ContentSource.create!(slug: "open", name: "Open", license_commercial: true, attribution: "open") }
  let(:store) { Pathname(Dir.mktmpdir("sentence-glosses")).join("sentence_glosses.jsonl") }

  before { stub_const("#{Huayu::SentenceGlossStore}::PATH", store) }

  after { store.dirname.rmtree if store.dirname.exist? }

  def rows = store.read.lines.map { |line| JSON.parse(line) }

  it "carries the Vietnamese translation into the sentence" do
    sentence = create(:lexeme, kind: :sentence, text: "我喝茶。", meanings: {}, content_sources: [source])
    Huayu::SentenceGlossStore.put("我喝茶。", en: "I drink tea.", ru: "Я пью чай.", vi: "Tôi uống trà.")

    described_class.new(io: StringIO.new).call

    expect(sentence.reload.meanings).to(
      eq({"en" => "I drink tea.", "ru" => "Я пью чай.", "vi" => "Tôi uống trà."})
    )
  end

  it "writes no empty Vietnamese field for a sentence without one" do
    Huayu::SentenceGlossStore.put("我喝茶。", en: "I drink tea.", ru: "Я пью чай.")

    expect(rows).to(eq([{"text" => "我喝茶。", "en" => "I drink tea.", "ru" => "Я пью чай."}]))
  end

  it "keeps a row that only Vietnamese still fills" do
    Huayu::SentenceGlossStore.put("我喝茶。", en: nil, ru: nil, vi: "Tôi uống trà.")

    expect(rows).to(eq([{"text" => "我喝茶。", "vi" => "Tôi uống trà."}]))
  end
end
