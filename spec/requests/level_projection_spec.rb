# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The level tab" do
  it "offers the level itself and points to the placement test" do
    get(profile_level_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("auth.level_field")))
    expect(response.body).to(include(placement_path))
  end

  it "no longer offers a visibility projection" do
    get(profile_level_path)

    expect(response.body).not_to(include("user[projection]"))
  end

  it "keeps the full dictionary visible whatever the level" do
    rare = create(:lexeme, kind: :word, text: "淼淼")
    @authenticated_user.update!(level: "zero")

    expect(Lexeme.visible_to(@authenticated_user)).to(include(rare))
  end

  it "saves the level from the tab" do
    patch("/profile", params: {tab: "level", user: {level: "3"}})

    expect(@authenticated_user.reload.level).to(eq("3"))
  end
end
