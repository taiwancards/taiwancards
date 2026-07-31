# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Moving through a sitting" do
  let(:deck) do
    Collection.create!(
      kind: :manual,
      name: "Loop",
      user: current_user,
      settings: {"facets" => %w[recognition reading]}
    )
  end

  let!(:fruit) { create(:lexeme, kind: :character, text: "果", meanings: {"en" => "fruit"}) }
  let!(:water) { create(:lexeme, kind: :character, text: "水", meanings: {"en" => "water"}) }

  let!(:word) do
    create(:lexeme, kind: :word, text: "水果", meanings: {"en" => "fruit"}).tap do |it|
      LexemeLink.create!(parent: it, child: water, position: 0)
      LexemeLink.create!(parent: it, child: fruit, position: 1)
    end
  end

  def head_token
    Study::Run.resume(session[:study]).head.to_s.split(":")
  end

  def grade(lexeme_id, facet, rating: "good")
    post(
      study_review_path,
      params: {lexeme_id:, facet:, rating:, session_id: session[:study]["sid"]},
      as: :turbo_stream
    )
  end

  before { deck.add_lexemes([word.id]) }

  it "puts the characters of a deck word into the sitting" do
    get(study_path(mode: "desk", collection_id: deck.id))

    tokens = Study::Run.resume(session[:study]).send(:all_tokens)
    expect(tokens.map { |token| token.split(":").first.to_i }).to(include(fruit.id, water.id))
  end

  it "drops a graded component character from the queue instead of serving it forever" do
    get(study_path(mode: "desk", collection_id: deck.id))
    before_count = Study::Run.resume(session[:study]).remaining

    grade(fruit.id, "recognition")

    after_count = Study::Run.resume(session[:study]).remaining
    expect(after_count).to(eq(before_count - 1))
  end

  it "works all the way through a sitting without repeating a passed card" do
    get(study_path(mode: "desk", collection_id: deck.id))
    total = Study::Run.resume(session[:study]).remaining
    served = []

    total.times do
      lexeme_id, facet = head_token
      break if lexeme_id.nil?

      served << [lexeme_id, facet]
      grade(lexeme_id, facet)
    end

    expect(served.size).to(eq(total))
    expect(served.uniq.size).to(eq(total))
    expect(Study::Run.resume(session[:study]).remaining).to(eq(0))
  end

  it "brings a missed card back but still finishes" do
    get(study_path(mode: "desk", collection_id: deck.id))
    lexeme_id, facet = head_token

    grade(lexeme_id, facet, rating: "again")

    expect(Study::Run.resume(session[:study]).queue).to(include("#{lexeme_id}:#{facet}"))
  end
end
