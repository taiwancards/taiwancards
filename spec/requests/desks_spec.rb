# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Desks" do
  before { Rails.application.load_seed }

  it "sends a returning person straight to their language desk" do
    user = create(:user, google_uid: "desk-uid")
    sign_in(user)

    expect(response).to(redirect_to("/en/desk"))
  end

  it "renders the Taiwanese home screen" do
    get("/desk")

    expect(response).to(have_http_status(:ok))
  end

  it "renders in the language the address asks for" do
    sign_in(create(:user, locale: "ru"))

    raw_get("/desk")
    expect(response).to(redirect_to("/ru/desk"))
    follow_redirect!
    expect(response.body).to(include("В колоде"))
  end

  def tocfl_level
    collection = Collection.create!(kind: :tocfl, name: "TOCFL Novice 1", level_tag: "Novice1", position: 0)
    collection.add_lexeme(create(:lexeme, kind: :word, text: "你"))
    Collection.reset_counters(collection.id, :collection_items)
    collection
  end

  it "shows an exam candidate the countdown, readiness by level and the mock test" do
    collection = tocfl_level
    user = sign_in(create(:user, prefs: {"goal" => "tocfl"}))
    StudyPlan.create!(user:, target_level: "Novice1", target_date: 30.days.from_now.to_date)

    get("/desk")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Readiness by TOCFL level", "30 days to the exam"))
    expect(response.body).to(include("/tocfl/#{collection.id}", "/mock/novice1", "/grammar?level=1"))
  end

  it "asks an exam candidate without a plan for the level and date" do
    tocfl_level
    sign_in(create(:user, prefs: {"goal" => "tocfl"}))

    get("/desk")

    expect(response.body).to(include("No exam date yet", "/plan/new"))
  end

  it "shows a class-goer their decks and sends the main button to them" do
    user = sign_in(create(:user, prefs: {"goal" => "classes"}))
    desk = Collection.create!(kind: :manual, name: "Lesson 3", user:)
    desk.add_lexeme(create(:lexeme, kind: :word, text: "課本"))

    get("/desk")

    expect(response.body).to(include("Lesson 3", "/study?mode=decks", "/desks/new?tab=import"))
    expect(response.body).not_to(include("Readiness by TOCFL level"))
  end

  it "points a class-goer without decks at making the first one" do
    sign_in(create(:user, prefs: {"goal" => "classes"}))

    get("/desk")

    expect(response.body).to(include("Start with a deck for your class", "href=\"/en/desks/new\""))
  end

  it "shows a guided learner the next step and the course by stage" do
    tocfl_level
    sign_in(create(:user, prefs: {"goal" => "guided", "start_level" => "experienced", "level" => "3"}))

    get("/desk")

    expect(response.body).to(include("Course by stage", "Your level", "/course"))
    expect(response.body).not_to(include("Readiness by TOCFL level"))
  end
end
