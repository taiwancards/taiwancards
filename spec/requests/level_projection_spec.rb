# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The level tab" do
  it "puts the level and what it hides on one page" do
    get(profile_level_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("auth.level_field")))
    expect(response.body).to(include(I18n.t("auth.projection_field")))
  end

  it "offers no slider, because the steps are not the same on every scale" do
    get(profile_level_path)

    expect(response.body).not_to(include("type=\"range\""))
  end

  it "names every option in the terms of its own scale" do
    get(profile_level_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("auth.projection_open"))))
    expect(response.body).to(include("常用"))
    expect(response.body).to(include("Novice1"))
    expect(response.body).to(include("TBCL: 1"))
  end

  it "moves the projection with one choice" do
    patch("/profile", params: {tab: "level", user: {projection: "tocfl:3"}})

    user = @authenticated_user.reload
    expect(user.visibility_scale).to(eq("tocfl"))
    expect(user.visibility_level).to(eq(3))
  end

  it "reads back as open once nothing is held above the level" do
    @authenticated_user.projection = User::PROJECTION_OPEN
    @authenticated_user.save!

    expect(@authenticated_user.reload.projection).to(eq(User::PROJECTION_OPEN))
    expect(@authenticated_user).to(be_full_visibility)
  end

  it "really shows everything on the open setting, including unlevelled words" do
    unlevelled = create(:lexeme, kind: :word, text: "淼淼")
    @authenticated_user.projection = User::PROJECTION_OPEN
    @authenticated_user.save!

    expect(Lexeme.visible_to(@authenticated_user)).to(include(unlevelled))
  end

  it "says how much the current choice hides" do
    create(:lexeme, kind: :word, text: "水果")
    create(:lexeme, kind: :word, text: "淼淼")

    get(profile_level_path)

    expect(response.body).to(match(/#{Regexp.escape(I18n.t("auth.projection_hides", hidden: 1, total: 2, share: 50))}/))
  end
end
