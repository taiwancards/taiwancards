# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The setup strip" do
  let(:user) { @authenticated_user }

  def strip
    get("/dict")
    response.body
  end

  it "asks a new account for its level" do
    expect(strip).to(include(I18n.t("setup.title"), onboarding_start_path))
  end

  it "disappears once the level is known" do
    user.update!(start_level: "zero")

    expect(strip).not_to(include(I18n.t("setup.title")))
  end

  it "stays out of a guest's way" do
    reset!

    get("/dict")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include(I18n.t("setup.title")))
  end
end
