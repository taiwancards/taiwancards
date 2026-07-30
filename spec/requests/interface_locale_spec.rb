# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Interface locale" do
  def sign_in_with_google(email:, uid:, accept_language: nil)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid:,
      info: {email:, name: "New"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )
    headers = accept_language ? {"HTTP_ACCEPT_LANGUAGE" => accept_language} : {}
    get("/auth/google_oauth2/callback", headers:)
  end

  it "picks the interface language from the browser on first sign-in", :no_auth do
    sign_in_with_google(email: "ru@example.com", uid: "ru-uid", accept_language: "ru-RU,ru;q=0.9,en;q=0.8")

    expect(User.find_by(email: "ru@example.com").locale).to(eq("ru"))
    get("/desk")
    expect(response.body).to(include(I18n.t("nav.help", locale: :ru)))
  end

  it "falls back to English when the browser asks for a language we do not have", :no_auth do
    sign_in_with_google(email: "jp@example.com", uid: "jp-uid", accept_language: "ja-JP,ja;q=0.9")

    expect(User.find_by(email: "jp@example.com").locale).to(eq("en"))
    expect(I18n.default_locale).to(eq(:en))
  end

  it "keeps the user's language even when a different one is passed in the URL" do
    sign_in(create(:user, locale: "ru"))

    get("/desk", params: {locale: "en"})

    expect(response.body).to(include(I18n.t("nav.help", locale: :ru)))
  end

  it "changes the language only from the profile" do
    user = sign_in(create(:user, locale: "en"))

    patch("/profile", params: {user: {locale: "ru"}})

    expect(user.reload.locale).to(eq("ru"))
    get("/desk")
    expect(response.body).to(include(I18n.t("nav.help", locale: :ru)))
  end

  it "no longer exposes a language toggle in the header" do
    sign_in(create(:user, locale: "en"))

    get("/desk")

    expect(response.body).not_to(include("locale=ru"))
  end
end
