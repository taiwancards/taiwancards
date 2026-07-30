# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::CardSet do
  let(:user) { Current.user }
  let(:collection) { Collection.create!(user:, kind: :manual, name: "Song") }

  def add(text)
    lexeme = create(:lexeme, kind: :word, text:, meanings: {"en" => text})
    collection.collection_items.create!(lexeme:, position: collection.collection_items.count)
    lexeme
  end

  before { 3.times { |i| add("詞#{i}") } }

  it "still serves deck items that were activated but never actually studied" do
    collection.lexemes.each { |lexeme| Lexemes::Activator.new.call(lexeme) }

    tokens = described_class.new.build(mode: "desk", collection:)

    expect(tokens).not_to(be_empty)
  end

  it "treats an item as fresh until it has been reviewed at least once" do
    lexeme = collection.lexemes.first
    Lexemes::Activator.new.call(lexeme)

    tokens = described_class.new.build(mode: "desk", collection:)
    ids = tokens.map { |token| token.split(":").first.to_i }

    expect(ids).to(include(lexeme.id))
  end

  it "drops an item from the fresh pool once it carries a real review state" do
    lexeme = collection.lexemes.first
    Lexemes::Activator.new.call(lexeme)
    LexemeMemory.owned_by(user).where(lexeme:).update_all(state: LexemeMemory.states[:review], due_at: 5.days.from_now)

    tokens = described_class.new.build(mode: "desk", collection:)
    ids = tokens.map { |token| token.split(":").first.to_i }.uniq

    expect(ids).not_to(include(lexeme.id))
  end

  it "runs everything again in redo mode, however well it is known" do
    collection.lexemes.each do |lexeme|
      Lexemes::Activator.new.call(lexeme)
      LexemeMemory
        .owned_by(user)
        .where(lexeme:)
        .update_all(state: LexemeMemory.states[:review], due_at: 30.days.from_now)
    end

    tokens = described_class.new.build(mode: "redo", collection:)
    ids = tokens.map { |token| token.split(":").first.to_i }.uniq

    expect(ids).to(match_array(collection.lexemes.pluck(:id)))
  end
end
