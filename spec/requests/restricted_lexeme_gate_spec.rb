# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Restricted entries reached by id", :aggregate_failures do
  let!(:word) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}) }
  let!(:secret) {
    create(:lexeme, kind: :phrase, text: "授權句子", meanings: {"en" => "licensed"}, restricted: true)
  }
  let(:deck) { Collection.create!(kind: :manual, name: "Mine", user: current_user) }

  def own_decks = Collection.desks_for(current_user)

  it "keeps a restricted id out of a new deck" do
    post("/desks", params: {lexeme_ids: [word.id, secret.id], name: "Probe"})

    expect(own_decks.find_by(name: "Probe").lexemes).to(contain_exactly(word))
  end

  it "does not build a deck from restricted ids alone" do
    post("/desks", params: {lexeme_ids: [secret.id], name: "Probe"})

    expect(own_decks.find_by(name: "Probe")).to(be_nil)
  end

  it "refuses to add a restricted id to an existing deck" do
    post("/desks/#{deck.id}/items", params: {lexeme_id: secret.id})

    expect(deck.reload.lexemes).to(be_empty)
  end

  it "does not mark a restricted id as known" do
    post("/desks/known", params: {lexeme_ids: [word.id, secret.id]})

    expect(LexemeMemory.owned_by(current_user).where(lexeme: secret)).to(be_empty)
    expect(LexemeMemory.owned_by(current_user).where(lexeme: word)).to(exist)
  end

  it "refuses a quick add of a restricted id" do
    post("/quick_add", params: {lexeme_id: secret.id})

    expect(CollectionItem.where(lexeme: secret)).to(be_empty)
    expect(LexemeMemory.owned_by(current_user).where(lexeme: secret)).to(be_empty)
  end

  it "ignores restricted ids in a triage sweep" do
    post("/triage", params: {known: [secret.id], normal: [secret.id]}, as: :json)

    expect(LexemeMemory.owned_by(current_user).where(lexeme: secret)).to(be_empty)
  end

  it "does not show a restricted entry that already sits in a deck" do
    deck.add_lexemes([word.id, secret.id])

    get("/desks/#{deck.id}")

    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("授權句子"))
  end

  context("for an account cleared for restricted content") do
    before { current_user.update!(restricted_content: true) }

    it "lets the restricted entry into a new deck" do
      post("/desks", params: {lexeme_ids: [word.id, secret.id], name: "Probe"})

      expect(own_decks.find_by(name: "Probe").lexemes).to(contain_exactly(word, secret))
    end

    it "lets a quick add of the restricted entry through" do
      post("/quick_add", params: {lexeme_id: secret.id})

      expect(CollectionItem.where(lexeme: secret)).to(exist)
    end
  end
end
