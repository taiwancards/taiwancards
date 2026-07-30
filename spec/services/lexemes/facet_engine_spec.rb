# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lexeme facet engine" do
  describe Lexemes::Facets do
    it "returns the configured facets per kind" do
      word = create(:lexeme, kind: :word)
      character = create(:lexeme, :character)
      expect(Lexemes::Facets.for(word)).to(eq(%w[recognition production reading tone writing]))
      expect(Lexemes::Facets.for(character)).to(eq(%w[recognition reading tone writing]))
      expect(Lexemes::Facets.for(character)).not_to(include("listening"))
    end
  end

  describe Lexemes::Activator do
    it "creates one activated memory per configured facet" do
      word = create(:lexeme, kind: :word)
      memories = Lexemes::Activator.new.call(word)

      expect(memories.map(&:facet)).to(contain_exactly("recognition", "production", "reading", "tone", "writing"))
      expect(memories).to(all(be_state_unseen))
      expect(memories.map(&:activated_at)).to(all(be_present))
      expect { Lexemes::Activator.new.call(word) }.not_to(change(LexemeMemory, :count))
    end
  end

  describe Lexemes::ReviewProcessor do
    it "advances one facet independently and logs a review" do
      word = create(:lexeme, kind: :word)
      memories = Lexemes::Activator.new.call(word)
      tone = memories.find(&:facet_tone?)

      Lexemes::ReviewProcessor.new.call(tone, rating: "again", session_id: SecureRandom.uuid)
      tone.reload

      expect(tone.reps).to(eq(1))
      expect(tone.due_at).to(be_present)
      expect(LexemeReview.where(lexeme: word).count).to(eq(1))
      expect(word.memories.where(facet: LexemeMemory.facets[:reading]).first.reps).to(eq(0))
    end
  end
end
