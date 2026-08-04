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
    raw_get("/desk")
    expect(response).to(redirect_to("/ru/desk"))
    follow_redirect!
    expect(response.body).to(include(I18n.t("nav.guide", locale: :ru)))
  end

  it "falls back to English when the browser asks for a language we do not have", :no_auth do
    sign_in_with_google(email: "jp@example.com", uid: "jp-uid", accept_language: "ja-JP,ja;q=0.9")

    expect(User.find_by(email: "jp@example.com").locale).to(eq("en"))
    expect(I18n.default_locale).to(eq(:en))
  end

  it "sends a person with no prefix in the address to the one their language asks for" do
    sign_in(create(:user, locale: "ru"))

    raw_get("/desk")

    expect(response).to(have_http_status(:moved_permanently))
    expect(response).to(redirect_to("/ru/desk"))
  end

  it "lets the address win over the stored language, so a shared link reads as it was sent" do
    sign_in(create(:user, locale: "ru"))

    get("/en/desk")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("nav.guide", locale: :en)))
    expect(response.body).not_to(include(I18n.t("nav.guide", locale: :ru)))
  end

  it "keeps the query string while adding the prefix" do
    sign_in(create(:user, locale: "en"))

    raw_get("/search?q=%E6%98%AF")

    expect(response).to(redirect_to("/en/search?q=%E6%98%AF"))
  end

  it "leaves the machine endpoints alone, so the health check answers rather than redirects" do
    raw_get("/up")

    expect(response).to(have_http_status(:ok))
  end

  it "changes the language only from the profile" do
    user = sign_in(create(:user, locale: "en"))

    patch("/profile", params: {user: {locale: "ru"}})

    expect(user.reload.locale).to(eq("ru"))
    raw_get("/desk")
    follow_redirect!
    expect(response.body).to(include(I18n.t("nav.guide", locale: :ru)))
  end

  it "sends a guest to the login in the language they were reading", :no_auth do
    raw_get("/ru/writing")

    expect(response).to(redirect_to("/ru/login"))
  end

  it "keeps the language on every page that asks for an account", :no_auth do
    %w[/desk /study /desks /triage /placement /practice /pronunciation /writing /reader /progress /profile]
      .each do |path|
        raw_get("/ru#{path}")

        expect(response.location).to(start_with("http://www.example.com/ru/"), "#{path} left the Russian pages")
      end
  end

  it "brings a guest back to the Russian page they wanted after signing in", :no_auth do
    raw_get("/ru/writing")
    sign_in_with_google(email: "back@example.com", uid: "back-uid")

    expect(response).to(redirect_to("/ru/writing"))
  end

  it "no longer exposes a language toggle in the header" do
    sign_in(create(:user, locale: "en"))

    get("/desk")

    expect(response.body).not_to(include("locale=ru"))
  end
end
