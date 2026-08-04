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

  it "renders the road with milestones and links each level" do
    collection = Collection.create!(kind: :tocfl, name: "TOCFL Novice 1", level_tag: "Novice1", position: 0)
    collection.add_lexeme(create(:lexeme, kind: :word, text: "你"))
    Collection.reset_counters(collection.id, :collection_items)

    get("/desk")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("Road to TOCFL"))
    expect(response.body).to(include("/tocfl/#{collection.id}"))
    expect(response.body).to(include("/mistakes"))
  end
end
