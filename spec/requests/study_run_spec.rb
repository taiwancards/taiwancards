# frozen_string_literal: true

require "rails_helper"

RSpec.describe "A study run" do
  def card
    body = response.body
    {
      lexeme_id: body[/<input[^>]*name="lexeme_id"[^>]*>/]&.[](/value="(\d+)"/, 1),
      facet: body[/<input[^>]*name="facet"[^>]*>/]&.[](/value="(\w+)"/, 1),
      session_id: body[/<input[^>]*name="session_id"[^>]*>/]&.[](/value="([^"]+)"/, 1)
    }
  end

  def answer(rating)
    post(
      "/study/review",
      params: card.merge(rating: rating, elapsed_ms: 800),
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    )
  end

  def big_desk(size)
    desk = Collection.create!(kind: :manual, name: "Everything", user: @authenticated_user)
    size.times { |n| desk.add_lexeme(create(:lexeme, kind: :word, text: "詞彙#{n}", meanings: {"en" => "x"})) }
    desk
  end

  it "runs a whole desk without stuffing the queue into the session cookie" do
    desk = big_desk(120)

    get("/study", params: {mode: "collection", collection_id: desk.id})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("360"))
  end

  it "keeps dealing fresh cards and never repeats one that was passed" do
    desk = big_desk(40)
    get("/study", params: {mode: "collection", collection_id: desk.id})

    seen = []
    20.times do
      seen << card.values_at(:lexeme_id, :facet)
      answer("good")
      expect(response).to(have_http_status(:ok))
    end

    expect(seen.uniq.size).to(eq(20))
  end

  it "brings a missed card back and counts it as still remaining" do
    desk = big_desk(2)
    get("/study", params: {mode: "collection", collection_id: desk.id})
    counter = %r{\d+ / (\d+) done}
    untouched = response.body[counter]
    total = untouched[counter, 1].to_i
    missed = card.values_at(:lexeme_id, :facet)

    answer("again")
    expect(response.body).to(include(untouched))

    (total - 1).times { answer("good") }
    expect(card.values_at(:lexeme_id, :facet)).to(eq(missed))
  end

  it "rebuilds the same queue after the page is reloaded mid-run" do
    desk = big_desk(3)
    get("/study", params: {mode: "collection", collection_id: desk.id})
    answer("good")
    following = card

    get("/study", params: {mode: "collection", collection_id: desk.id})

    expect(response).to(have_http_status(:ok))
    expect(card[:session_id]).not_to(eq(following[:session_id]))
  end

  it "shows the finished screen instead of failing when the session is gone" do
    post("/study/review", params: {lexeme_id: "1", facet: "recognition", rating: "good"})

    expect(response).to(redirect_to(study_path(mode: "daily")))
  end

  it "survives a collection run with no collection behind it" do
    get("/study", params: {mode: "collection"})

    expect(response).to(have_http_status(:ok))
  end

  it "grades a listening card" do
    lexeme = create(:lexeme, kind: :word, text: "聽力", meanings: {"en" => "x"})
    memory = LexemeMemory.create!(lexeme:, user: @authenticated_user, facet: :listening, activated_at: Time.current)

    expect { Lexemes::ReviewProcessor.new.call(memory, rating: "good") }
      .to(change(LexemeReview, :count).by(1))
  end
end
