# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The level next to the study mode" do
  it "sits on the profile beside the mode and points to the placement test" do
    get(profile_path)

    expect(response.body).to(include("id=\"level\"", "user[level]", placement_path))
    expect(response.body).not_to(include("user[projection]"))
  end

  it "sends the old level page to the profile" do
    get(profile_level_path)

    expect(response).to(redirect_to(profile_path(anchor: "level")))
    expect(response).to(have_http_status(:moved_permanently))
  end

  it "explains a step up and a step down differently" do
    @authenticated_user.update!(level: "3")

    get(profile_path)

    up = I18n.t("auth.level_change.up", level: "TBCL 4 · TOCFL A2", next: "TBCL 5 · TOCFL B1")
    down = I18n.t("auth.level_change.down", level: "TBCL 1 · TOCFL Novice 1", next: "TBCL 2 · TOCFL Novice 2")
    body = CGI.unescapeHTML(response.body)
    expect(body).to(include(up, down))
  end

  it "keeps the full dictionary visible whatever the level" do
    rare = create(:lexeme, kind: :word, text: "淼淼")
    @authenticated_user.update!(level: "zero")

    expect(Lexeme.visible_to(@authenticated_user)).to(include(rare))
  end

  it "saves the level from the profile" do
    patch("/profile", params: {user: {level: "3"}})

    expect(@authenticated_user.reload.level).to(eq("3"))
  end
end
