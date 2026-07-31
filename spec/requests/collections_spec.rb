# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Desks (collections)" do
  def desk_for(user, name)
    Collection.create!(kind: :manual, name:, user:)
  end

  it "creates a desk from selected lexemes" do
    word = create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"})

    expect do
      post("/desks", params: {name: "Trip", lexeme_ids: [word.id]})
    end
      .to(change(Collection.where(kind: :manual), :count).by(1))

    desk = Collection.desks_for(@authenticated_user).last
    expect(desk.name).to(eq("Trip"))
    expect(desk.lexemes).to(include(word))
    expect(response).to(redirect_to(my_desk_path(desk)))
  end

  it "renders the new desk form" do
    get("/desks/new")
    expect(response).to(have_http_status(:ok))
  end

  it "renders a desk page with its words and facet toggles" do
    desk = desk_for(@authenticated_user, "ShowMe")
    desk.add_lexeme(create(:lexeme, kind: :word, text: "課本", meanings: {"en" => "textbook"}))

    get("/desks/#{desk.id}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("課本"))
  end

  it "previews words parsed from pasted text" do
    create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"})

    post("/desks/preview", params: {text: "我去學校"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
  end

  it "offers only Taiwanese Mandarin words as cards, whatever else the text holds" do
    create(:lexeme, kind: :word, text: "小姐", meanings: {"en" => "miss"})

    post("/desks/preview", params: {text: "小姐\nxiǎojiě\nN\nбарышня, госпожа\n\nㄋㄧˇ"})
    expect(response).to(have_http_status(:ok))
    expect(preview_candidates).to(eq(["小姐"]))
    expect(preview_payload["lines"].flatten.select { |token| token["k"] == 2 }.map { |token| token["t"] })
      .to(eq(["小姐"]))
  end

  it "lists only the current user's desks" do
    desk_for(@authenticated_user, "MyTripDesk")
    desk_for(create(:user), "OtherPersonDesk")

    get("/desks")

    expect(response.body).to(include("MyTripDesk"))
    expect(response.body).not_to(include("OtherPersonDesk"))
  end

  it "updates the facet toggles" do
    desk = desk_for(@authenticated_user, "Facets")

    patch("/desks/#{desk.id}", params: {collection: {facets: %w[recognition writing]}})

    expect(desk.reload.study_facets).to(contain_exactly("recognition", "writing"))
  end

  it "adds and removes an item" do
    desk = desk_for(@authenticated_user, "Items")
    word = create(:lexeme, kind: :word, text: "書")

    post("/desks/#{desk.id}/items", params: {lexeme_id: word.id})
    expect(desk.reload.lexemes).to(include(word))

    delete("/desks/#{desk.id}/items/#{word.id}")
    expect(desk.reload.lexemes).not_to(include(word))
  end

  it "returns not found for another user's desk" do
    other = desk_for(create(:user), "Secret")

    get("/desks/#{other.id}")

    expect(response).to(have_http_status(:not_found))
  end

  it "creates a deck drilling only what was ticked" do
    sign_in(create(:user))
    lexeme = create(:lexeme, text: "測試")

    post(
      desks_path,
      params: {lexeme_ids: [lexeme.id], name: "Sound only", facets: %w[recognition production reading tone]}
    )

    desk = Collection.find_by(name: "Sound only")
    expect(desk.study_facets).to(eq(%w[recognition production reading tone]))
    expect(desk.study_facets).not_to(include("writing"))
  end

  it "falls back to the default facets when none are ticked" do
    sign_in(create(:user))
    lexeme = create(:lexeme, text: "預設")

    post(desks_path, params: {lexeme_ids: [lexeme.id], name: "Default"})

    desk = Collection.find_by(name: "Default")
    expect(desk.settings["facets"]).to(be_nil)
    expect(Study::CardSet.new.send(:swipe_facets_for, desk)).to(eq(Study::CardSet::SWIPE_FACETS))
  end

  it "ignores a facet that is not real" do
    sign_in(create(:user))
    lexeme = create(:lexeme, text: "亂寫")

    post(desks_path, params: {lexeme_ids: [lexeme.id], name: "Bogus", facets: %w[recognition nonsense]})

    expect(Collection.find_by(name: "Bogus").study_facets).to(eq(%w[recognition]))
  end
end
