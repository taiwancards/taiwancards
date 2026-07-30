# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::Activator do
  let(:user) { create(:user) }

  before { Current.user = user }

  after { Current.reset }

  describe "#call_many" do
    it "activates every facet of every lexeme" do
      lexemes = create_list(:lexeme, 3)

      described_class.new.call_many(lexemes)

      expect(LexemeMemory.owned_by(user).active.distinct.count(:lexeme_id)).to(eq(3))
      expect(LexemeMemory.owned_by(user).where(lexeme_id: lexemes.first.id).count).to(
        eq(Lexemes::Facets.for(lexemes.first).length)
      )
    end

    it "runs a constant number of queries whatever the batch size" do
      small = create_list(:lexeme, 2)
      large = create_list(:lexeme, 20)

      for_small = count_queries { described_class.new.call_many(small) }.count
      for_large = count_queries { described_class.new.call_many(large) }.count

      expect(for_large).to(eq(for_small))
    end

    it "is idempotent and does not reset an existing activation" do
      lexeme = create(:lexeme)
      described_class.new(now: 3.days.ago).call_many([lexeme])
      first = LexemeMemory.owned_by(user).find_by(lexeme_id: lexeme.id).activated_at

      described_class.new.call_many([lexeme])
      again = LexemeMemory.owned_by(user).find_by(lexeme_id: lexeme.id).activated_at

      expect(again).to(be_within(1.second).of(first))
      expect(LexemeMemory.owned_by(user).where(lexeme_id: lexeme.id).count).to(
        eq(Lexemes::Facets.for(lexeme).length)
      )
    end

    it "leaves an empty batch alone" do
      expect { described_class.new.call_many([]) }.not_to(change(LexemeMemory, :count))
    end

    it "agrees with the single-lexeme path" do
      one = create(:lexeme)
      other = create(:lexeme)

      described_class.new.call(one)
      described_class.new.call_many([other])

      expect(LexemeMemory.owned_by(user).where(lexeme_id: other.id).pluck(:facet).sort).to(
        eq(LexemeMemory.owned_by(user).where(lexeme_id: one.id).pluck(:facet).sort)
      )
    end
  end

  describe "content source visibility cache" do
    it "asks the sources table once per user within a request" do
      create(:lexeme)

      queries = count_queries { 3.times { Lexeme.visible_to(user).to_a } }.count

      sources = count_queries { ContentSource.visible_to(user).pluck(:id) }.count

      expect(queries).to(eq(3 + sources))
    end

    it "notices a source being switched off" do
      source = ContentSource.create!(license_commercial: true, slug: "s", name: "S", attribution: "a", enabled: true)
      Current.source_ids_for(user)

      source.update!(enabled: false)

      expect(Current.source_ids_for(user)).not_to(include(source.id))
    end
  end
end
