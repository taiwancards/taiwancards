# frozen_string_literal: true

require "rails_helper"

RSpec.describe Graded::Shelf do
  let(:user) { create(:user) }

  def know(kind, count)
    lexemes = Array.new(count) { |index| create(:lexeme, kind:, text: "#{kind}-#{index}") }
    rows = lexemes.map do |lexeme|
      {
        user_id: user.id,
        lexeme_id: lexeme.id,
        facet: LexemeMemory.facets[:recognition],
        state: LexemeMemory.states[:review]
      }
    end

    LexemeMemory.insert_all!(rows)
  end

  it "starts a beginner on the first tier" do
    expect(described_class.new(user).tier.id).to(eq(Graded::Library.tiers.first))
  end

  it "follows the stated level" do
    user.update!(level: "4")

    expect(described_class.new(user).tier.id).to(eq("words1000"))
  end

  it "moves past the level once enough characters are known" do
    know(:character, 300)

    expect(described_class.new(user).tier.id).to(eq("chars300"))
  end

  it "suggests the first unread text and moves on past a finished tier" do
    tier = Graded::Library.tiers.first
    Graded::Library.texts(tier).each { |text| GradedCompletion.record(user:, text_id: text.id) }

    upcoming = described_class.new(user).next_text

    expect(upcoming).to(eq(Graded::Library.texts(Graded::Library.tiers.second).first))
  end

  it "counts read texts per tier" do
    tier = Graded::Library.tiers.first
    GradedCompletion.record(user:, text_id: Graded::Library.texts(tier).first.id)

    progress = described_class.new(user).progress(tier)

    expect([progress.read, progress.total]).to(eq([1, Graded::Library.texts(tier).size]))
  end
end
