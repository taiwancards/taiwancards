# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Deck screens" do
  let!(:school) { create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}, data: {"pos" => "N"}) }
  let!(:go) { create(:lexeme, kind: :word, text: "去", meanings: {"en" => "to go"}, data: {"pos" => "Vi"}) }

  let(:deck) do
    Collection.create!(kind: :manual, name: "Trip", user: current_user).tap { |it| it.add_lexemes([school.id]) }
  end

  it "renders My decks with its groups" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    group.add_collections([deck.id])

    get("/desks")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Reading"))
    expect(response.body).to(include("Trip"))
  end

  it "renders a group page with the decks it holds and the ones it could take" do
    group = CollectionGroup.create!(user: current_user, name: "Reading")
    group.add_collections([deck.id])
    Collection.create!(kind: :manual, name: "Spare", user: current_user)

    get("/groups/#{group.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Trip"))
    expect(response.body).to(include("Spare"))
  end

  it "renders a deck page with its cards and the add-cards form" do
    get("/desks/#{deck.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).to(include(I18n.t("desks.add_cards_title")))
  end

  it "renders the shared-links page" do
    Decks::Sharing.publish_deck(deck, user: current_user)

    get("/shares")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Trip"))
  end

  it "renders the study settings page" do
    get("/settings/edit")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("settings.session_size")))
  end

  it "renders the whole text and a panel for the word details" do
    post("/desks/preview", params: {text: "我去學校"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("desks.panel_empty")))
    expect(response.body).to(include(I18n.t("desks.panel_score")))
    expect(preview_payload["lines"].flatten.map { |token| token["t"] }.join).to(eq("我去學校"))
  end

  it "carries reading, meaning, both level scales and our score for every candidate" do
    create(
      :lexeme,
      kind: :word,
      text: "課本",
      readings: {"zhuyin" => "ㄎㄜˋ ㄅㄣˇ"},
      meanings: {"en" => "textbook"},
      score: 12.5,
      data: {"tocfl_level" => "A1", "tbcl_grade" => 2, "freq_rank" => 900}
    )

    post("/desks/preview", params: {text: "課本"})
    entry = preview_payload["candidates"].find { |row| row["t"] == "課本" }

    expect(entry).to(include("r" => "ㄎㄜˋ ㄅㄣˇ", "m" => "textbook", "l" => "A1", "b" => 2, "f" => 900))
    expect(entry["c"]).to(eq(12.5))
    expect(entry["u"]).to(include("/dict/"))
  end

  it "keeps the level filter on the TOCFL scale alone" do
    create(:lexeme, kind: :word, text: "課本", meanings: {"en" => "textbook"}, data: {"tocfl_level" => "A1"})
    create(:lexeme, kind: :word, text: "老師", meanings: {"en" => "teacher"}, data: {"tbcl_grade" => 3})

    post("/desks/preview", params: {text: "課本老師"})

    expect(preview_payload["candidates"].map { |row| row["l"] }).to(contain_exactly("A1", nil))
  end

  it "keeps every foreign stretch of the text visible but unusable as a card" do
    post("/desks/preview", params: {text: "Hello 學校 привет"})

    foreign = preview_payload["lines"].flatten.select { |token| token["k"].zero? }.map { |token| token["t"] }
    expect(foreign.join).to(include("Hello"))
    expect(foreign.join).to(include("привет"))
    expect(preview_candidates).to(eq(["學校"]))
  end

  it "renders the preview of a big text in a fixed number of queries" do
    words = Array.new(60) { |index| [0x4E00 + (index * 2), 0x4E01 + (index * 2)].pack("U*") }
    words.each { |text| create(:lexeme, kind: :word, text:) }
    text = ([words.join("。")] * 5).join("\n")

    report = count_queries { post("/desks/preview", params: {text:}) }

    expect(response).to(have_http_status(:ok))
    expect(report).to(repeat_no_query_more_than(3))
  end

  it "renders My decks without a query per deck" do
    Array.new(12) { |index| Collection.create!(kind: :manual, name: "Deck #{index}", user: current_user) }

    report = count_queries { get("/desks") }

    expect(response).to(have_http_status(:ok))
    expect(report).to(repeat_no_query_more_than(3))
  end
end
