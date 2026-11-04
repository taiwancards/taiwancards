# frozen_string_literal: true

require "rails_helper"

RSpec.describe "The account language rules the interface" do
  let(:learner) { create(:user, locale: "ru") }

  before { sign_in(learner) }

  it "opens a link in another language in the account's language, keeping the rest of the address" do
    raw_get("/vi/desk?from=link")

    expect(response).to(redirect_to("/ru/desk?from=link"))
    expect(learner.reload.locale).to(eq("ru"))
  end

  it "shows the same language the letters are written in" do
    raw_get("/vi/desk")
    follow_redirect!
    delivery = Reminders::Dispatch
      .new
      .call(
        [Reminders::Planner::Plan.new(user: learner, trigger: "due_cards", count: 5)]
      )
      .first

    expect(response.body).to(match(/<html[^>]*lang="ru"/))
    expect(delivery.locale).to(eq("ru"))
  end

  it "stays on a page already in the account's language" do
    raw_get("/ru/desk")

    expect(response).to(have_http_status(:ok))
  end

  it "moves everything to the new language once the switch is used, without bouncing back" do
    post("/locale/vi", headers: {"HTTP_REFERER" => "http://www.example.com/ru/desk"})
    expect(response).to(redirect_to("http://www.example.com/vi/desk"))

    follow_redirect!
    expect(response).to(have_http_status(:ok))
    expect(learner.reload.locale).to(eq("vi"))
  end

  it "carries a message through the extra step" do
    patch("/ru/profile", params: {user: {locale: "vi"}})
    expect(response).to(redirect_to(profile_path(locale: "ru")))

    follow_redirect!
    expect(response).to(redirect_to("/vi/profile"))

    follow_redirect!
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("auth.profile_saved", locale: :ru))))
  end

  it "leaves requests that are not page views alone" do
    raw_get("/vi/desk", headers: {"X-Requested-With" => "XMLHttpRequest"})

    expect(response).not_to(redirect_to("/ru/desk"))
  end

  it "keeps the page language while an admin looks through someone's account" do
    sign_in(create(:user, :admin, locale: "en"))
    post(admin_impersonate_path(learner))
    raw_get("/en/desk")

    expect(response).to(have_http_status(:ok))
  end

  it "switches language from the flags through the account, not through a link that would bounce back" do
    raw_get("/ru/login")

    expect(response.body).to(include("action=\"/locale/vi\""))
    expect(response.body).not_to(include("href=\"/vi/login\""))
  end
end

RSpec.describe "A guest reads the language of the address", :no_auth do
  it "moves to the account's language once a link in another language leads through the login" do
    create(:user, email: "linked@example.com", locale: "ru", google_uid: "guid-linked")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "guid-linked",
      info: {email: "linked@example.com", name: "Learner"},
      credentials: {token: "access-token", refresh_token: "refresh-token", expires_at: 2.hours.from_now.to_i}
    )

    raw_get("/vi/desk")
    expect(response).to(redirect_to("/vi/login"))

    post("/auth/google_oauth2?intent=sign_in&locale=vi")
    follow_redirect!
    expect(response).to(redirect_to("/vi/desk"))

    follow_redirect!
    expect(response).to(redirect_to("/ru/desk"))

    follow_redirect!
    expect(response.body).to(match(/<html[^>]*lang="ru"/))
    expect(response.body).to(include(I18n.t("auth.signed_in", locale: :ru)))
  end

  it "serves the page as linked" do
    raw_get("/vi/login")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(match(/<html[^>]*lang="vi"/))
  end

  it "lets the address win over a language remembered in the browser" do
    raw_get("/vi/login", headers: {"HTTP_COOKIE" => "locale=ru"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(match(/<html[^>]*lang="vi"/))
  end
end
