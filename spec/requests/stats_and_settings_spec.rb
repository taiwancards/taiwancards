# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stats and settings" do
  before { Rails.application.load_seed }

  it "renders the progress summary" do
    get("/progress")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("stats.streak")))
  end

  it "clamps study settings to their permitted range" do
    patch(
      "/settings",
      params: {
        setting: {desired_retention: "0.5", daily_new_limit: "9999", session_size: "0", learn_ahead_minutes: "15"}
      }
    )

    preferences = Study::Preferences.for(current_user.reload)
    expect(preferences.desired_retention).to(eq(0.7))
    expect(preferences.daily_new_limit).to(eq(500))
    expect(preferences.session_size).to(eq(1))
    expect(preferences.learn_ahead_minutes).to(eq(15))
  end

  it "keeps one person's study settings off everybody else's" do
    patch("/settings", params: {setting: {daily_new_limit: "77"}})

    expect(Study::Preferences.for(current_user.reload).daily_new_limit).to(eq(77))
    expect(Setting.instance.daily_new_limit).to(eq(Setting::DEFAULTS["daily_new_limit"]))
    expect(Study::Preferences.for(create(:user)).daily_new_limit).to(eq(Setting::DEFAULTS["daily_new_limit"]))
  end

  it "restores a person to the installation defaults" do
    patch("/settings", params: {setting: {daily_new_limit: "77"}})
    delete("/settings")

    expect(Study::Preferences.for(current_user.reload).daily_new_limit).to(eq(Setting::DEFAULTS["daily_new_limit"]))
  end

  it "serves the Hotwire Native path configuration" do
    get("/configurations/ios")
    rules = response.parsed_body["rules"]
    expect(rules.first["properties"]["context"]).to(eq("modal"))
    expect(rules.last["patterns"]).to(eq([".*"]))
  end
end
