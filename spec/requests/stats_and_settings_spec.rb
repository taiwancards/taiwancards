# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stats and settings" do
  before { Rails.application.load_seed }

  it "renders the progress summary" do
    get("/progress")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("stats.streak")))
  end

  it "updates settings with clamping" do
    patch(
      "/settings",
      params: {setting: {desired_retention: "0.5", daily_new_limit: "9999", learn_ahead_minutes: "15"}}
    )

    settings = Setting.instance
    expect(settings.desired_retention).to(eq(0.7))
    expect(settings.daily_new_limit).to(eq(500))
    expect(settings.learn_ahead_minutes).to(eq(15))
  end

  it "serves the Hotwire Native path configuration" do
    get("/configurations/ios")
    rules = response.parsed_body["rules"]
    expect(rules.first["properties"]["context"]).to(eq("modal"))
    expect(rules.last["patterns"]).to(eq([".*"]))
  end
end
