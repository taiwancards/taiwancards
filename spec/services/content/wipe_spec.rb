# frozen_string_literal: true

require "rails_helper"

RSpec.describe Content::Wipe do
  let(:user) { User.create!(email: "learner@example.com", password: "password123") }
  let(:io) { StringIO.new }

  let(:source) do
    ContentSource.create!(
      slug: "src",
      license_commercial: true,
      name: "Src",
      enabled: true,
      enabled_for_admins: true,
      attribution: "Src."
    )
  end

  let!(:character) { Lexeme.create!(kind: :character, text: "捷") }
  let!(:word) { Lexeme.create!(kind: :word, text: "捷運") }
  let!(:collocation) { Lexeme.create!(kind: :collocation, text: "捷運站") }

  let!(:sentence) do
    lexeme = Lexeme.new(kind: :sentence, text: "我搭捷運去上班。")
    lexeme.lexeme_content_sources.build(content_source: source)
    lexeme.save!
    lexeme
  end

  let!(:card) { LexemeMemory.create!(user:, lexeme: word, facet: LexemeMemory.facets.keys.first) }

  describe "refresh" do
    it "keeps characters and words with the same ids" do
      character_id = character.id
      word_id = word.id

      described_class.new(full: false, io:).call

      expect(Lexeme.find_by(text: "捷")&.id).to(eq(character_id))
      expect(Lexeme.find_by(text: "捷運")&.id).to(eq(word_id))
    end

    it "keeps the learner's progress" do
      expect { described_class.new(full: false, io:).call }.not_to(change { LexemeMemory.count })
      expect(card.reload.lexeme).to(eq(word))
    end

    it "drops sentences and collocations, which are re-derivable" do
      described_class.new(full: false, io:).call

      expect(Lexeme.where(kind: :sentence)).to(be_empty)
      expect(Lexeme.where(kind: :collocation)).to(be_empty)
    end

    it "leaves no orphaned attribution behind" do
      described_class.new(full: false, io:).call
      expect(LexemeContentSource.count).to(eq(0))
    end
  end

  describe "full" do
    it "removes everything, progress included" do
      described_class.new(full: true, io:).call

      expect(Lexeme.count).to(eq(0))
      expect(LexemeMemory.count).to(eq(0))
    end
  end
end
