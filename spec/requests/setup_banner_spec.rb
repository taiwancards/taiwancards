# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The setup strip" do
  let(:user) { @authenticated_user }

  def strip
    get("/dict")
    response.body
  end

  it "asks a new account for both the tour and the level" do
    expect(strip).to(include(I18n.t("intro.setup.tour"), I18n.t("intro.setup.level")))
  end

  it "cannot be dismissed, only satisfied" do
    body = strip

    expect(body).to(include(CGI.escapeHTML(intro_start_path)))
    expect(body).to(include(onboarding_start_path))
    expect(body).not_to(include(I18n.t("intro.dismiss")))
  end

  it "drops the level once it is known" do
    user.update!(start_level: "zero")

    expect(strip).not_to(include(I18n.t("intro.setup.level")))
  end

  it "drops the tour once it is done" do
    user.intro.finish!

    expect(strip).not_to(include(I18n.t("intro.setup.tour")))
  end

  it "disappears entirely once both are settled" do
    user.intro.finish!
    user.update!(start_level: "zero")

    expect(strip).not_to(include(I18n.t("intro.setup.title")))
  end

  it "stays out of a guest's way" do
    reset!

    get("/dict")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include(I18n.t("intro.setup.title")))
  end
end
