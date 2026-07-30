# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stated limits" do
  it "sets expectations before the starting question is asked", :aggregate_failures do
    get("/start")

    expect(response.body).to(include(I18n.t("onboarding.limits.heading")))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("onboarding.limits.gap"))))
    expect(response.body.index(I18n.t("onboarding.limits.heading")))
      .to(be < response.body.index(I18n.t("onboarding.question")))
  end

  it "names what the app does not do, in both locales", :aggregate_failures do
    %i[en ru].each do |locale|
      gap = I18n.t("onboarding.limits.gap", locale:)
      landing = I18n.t("landing.complement.limits", locale:)

      expect(gap).to(be_present)
      expect(landing).to(be_present)
    end
  end

  it "states the same limits on the landing page", :no_auth do
    get(root_path)

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("landing.complement.limits"))))
  end
end
