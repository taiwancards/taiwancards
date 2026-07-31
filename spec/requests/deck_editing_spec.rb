# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Editing a deck" do
  let!(:school) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let!(:book) { create(:lexeme, kind: :word, text: "課本", meanings: {"en" => "textbook"}) }
  let(:deck) { Collection.create!(kind: :manual, name: "Trip", user: current_user) }

  it "adds the words of a pasted text to an existing deck" do
    deck.add_lexemes([school.id])

    post("/desks/#{deck.id}/cards", params: {text: "課本"})

    expect(deck.reload.lexemes.map(&:text)).to(contain_exactly("學校", "課本"))
    expect(deck.items_count).to(eq(2))
  end

  it "never adds the same card twice" do
    deck.add_lexemes([school.id])

    post("/desks/#{deck.id}/cards", params: {text: "學校 學校"})

    expect(deck.reload.items_count).to(eq(1))
  end

  it "removes several cards in one request" do
    deck.add_lexemes([school.id, book.id])

    delete("/desks/#{deck.id}/items", params: {lexeme_ids: [school.id, book.id]})

    expect(deck.reload.items_count).to(eq(0))
    expect(deck.lexemes).to(be_empty)
  end

  it "keeps the card counter exact through adds and removes" do
    deck.add_lexemes([school.id, book.id])
    deck.remove_lexemes([school.id])
    deck.add_lexemes([school.id])

    expect(deck.reload.items_count).to(eq(deck.collection_items.count))
  end

  it "keeps the progress on a word when the deck holding it is deleted" do
    deck.add_lexemes([school.id])
    Lexemes::Activator.new.call_many([school])
    expect(LexemeMemory.owned_by(current_user).where(lexeme_id: school.id)).to(exist)

    delete("/desks/#{deck.id}")

    expect(LexemeMemory.owned_by(current_user).where(lexeme_id: school.id)).to(exist)
  end

  it "refuses to exceed the card ceiling" do
    stub_const("Collection::MAX_ITEMS", 1)
    deck.add_lexemes([school.id])

    post("/desks/#{deck.id}/items", params: {lexeme_id: book.id})

    expect(deck.reload.items_count).to(eq(1))
    expect(flash[:alert]).to(eq(I18n.t("desks.full", limit: 1)))
  end

  it "pages a deck rather than rendering every card at once" do
    stub_const("CollectionsController::PER_PAGE", 1)
    deck.add_lexemes([school.id, book.id])

    get("/desks/#{deck.id}")

    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("課本"))
  end

  it "writes a whole deck without a query per card" do
    words = Array.new(30) { |index| create(:lexeme, kind: :word, text: "批次#{index}") }
    target = deck

    report = count_queries { target.add_lexemes(words.map(&:id)) }

    expect(report.count).to(be <= 3)
    expect(deck.reload.items_count).to(eq(30))
  end
end
