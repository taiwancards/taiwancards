# frozen_string_literal: true

require "rails_helper"

RSpec.describe Textbook::Purge do
  let(:io) { StringIO.new }

  let!(:word) do
    Lexeme.create!(kind: :word, text: "捷運", sources: ["Textbook B1L03", "TOCFL A2"])
  end

  let!(:only_textbook_word) do
    Lexeme.create!(kind: :word, text: "悠遊卡", sources: ["Textbook B1L04"])
  end

  let!(:character) do
    Lexeme.create!(kind: :character, text: "捷", sources: ["Textbook B1L03"])
  end

  let!(:phrase) do
    Lexeme.create!(
      kind: :phrase,
      text: "我搭捷運去上班。",
      sources: ["Textbook B1L03"],
      restricted: true,
      data: {"sentence" => true}
    )
  end

  let!(:clean_word) do
    Lexeme.create!(kind: :word, text: "便利商店", sources: ["Taiwan everyday"])
  end

  before { LexemeLink.create!(parent: phrase, child: word, position: 0) }

  describe "what survives" do
    it "keeps a word that arrived only through the textbook" do
      described_class.new(io:).call
      expect(Lexeme.find_by(text: "悠遊卡")).to(be_present)
    end

    it "keeps words, characters and unrelated entries alike" do
      expect { described_class.new(io:).call }.not_to(
        change { Lexeme.where(kind: %i[word character radical]).count }
      )
      expect(Lexeme.find_by(text: "捷運")).to(be_present)
      expect(Lexeme.find_by(text: "捷")).to(be_present)
      expect(Lexeme.find_by(text: "便利商店")).to(be_present)
    end

    it "leaves list membership alone while stripping the textbook tag" do
      described_class.new(io:).call
      expect(word.reload.sources).to(eq(["TOCFL A2"]))
      expect(only_textbook_word.reload.sources).to(be_empty)
      expect(clean_word.reload.sources).to(eq(["Taiwan everyday"]))
    end
  end

  describe "what goes" do
    it "removes the sentence" do
      expect { described_class.new(io:).call }.to(change { Lexeme.where(kind: :phrase).count }.from(1).to(0))
    end

    it "removes the links that pointed at it, leaving no orphans" do
      described_class.new(io:).call
      expect(LexemeLink.where(parent_id: phrase.id)).to(be_empty)
      expect(LexemeLink.where(child_id: phrase.id)).to(be_empty)
    end
  end

  describe "dry run" do
    it "counts without touching anything" do
      expect { described_class.new(io:).call(dry_run: true) }.not_to(change { Lexeme.count })
      expect(io.string).to(include("3"))
    end
  end
end
