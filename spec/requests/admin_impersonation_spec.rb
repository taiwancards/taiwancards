# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin impersonation" do
  let(:admin) { create(:user, :admin, locale: "en") }
  let(:member) {
    create(:user, locale: "ru", prefs: {"mobile_tabs" => %w[deck words]})
  }

  it "shows the app exactly as the member sees it" do
    sign_in(admin)

    post(admin_impersonate_path(member))
    expect(response).to(redirect_to("/ru"))

    in_locale(:ru) { get("/desk") }
    expect(response.body).to(include(I18n.t("nav.progress", locale: :ru)))
    expect(response.body).to(include("/ru/dict"))
    expect(response.body).to(include(I18n.t("admin.impersonation_stop", locale: :ru)))
    expect(response.body).to(include("<strong class=\"font-semibold\">#{member.email}</strong>"))
    expect(response.body).not_to(include(admin.email))
    expect(response.body).to(include("content=\"no-cache\" name=\"turbo-cache-control\""))
  end

  it "shows the member over a remote connection too" do
    remote = {"REMOTE_ADDR" => "203.0.113.7"}
    sign_in(admin)

    post(admin_impersonate_path(member), env: remote)
    in_locale(:ru) { get("/desk", env: remote) }

    expect(response.body).to(include("<strong class=\"font-semibold\">#{member.email}</strong>"))
    expect(response.body).not_to(include(admin.email))
  end

  it "keeps the admin session underneath and can be stopped" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    delete(admin_stop_impersonating_path)

    expect(response).to(redirect_to(admin_users_path))
    get(admin_users_path)
    expect(response).to(have_http_status(:ok))
  end

  it "applies the member's own permissions while impersonating" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    get(admin_users_path)

    expect(response).to(redirect_to(root_path))
  end

  it "bounces every change back with a read-only notice" do
    sign_in(admin)
    post(admin_impersonate_path(member))
    before = member.reload.attributes

    patch(
      "/en/profile",
      params: {user: {name: "Renamed", level: 5}},
      headers: {"Referer" => "http://www.example.com/en/profile"}
    )

    expect(response).to(have_http_status(:see_other))
    expect(response).to(redirect_to("/en/profile"))
    expect(flash[:alert]).to(eq(I18n.t("admin.impersonation_read_only")))
    expect(member.reload.attributes).to(eq(before))
  end

  it "answers script requests with a refusal instead of saving" do
    sign_in(admin)
    post(admin_impersonate_path(member))
    before = member.reload.attributes

    post("/en/study/review", params: {lexeme_id: 1, rating: "good"}, as: :json)

    expect(response).to(have_http_status(:forbidden))
    expect(response.parsed_body["error"]).to(eq(I18n.t("admin.impersonation_read_only")))
    expect(member.reload.attributes).to(eq(before))
  end

  it "rolls back what a page writes just by being opened" do
    sign_in(admin)
    post(admin_impersonate_path(member))
    before = member.reload.attributes

    get("/en/tones/drill")
    get("/en/pronunciation/warmup")

    expect(response).to(have_http_status(:ok))
    expect(member.reload.attributes).to(eq(before))
    expect(VoiceProfile.where(user: member)).to(be_empty)
  end

  it "switches the language for the admin's browser only" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    post(locale_path(code: "en"), headers: {"Referer" => "http://www.example.com/ru/desk"})

    expect(response).to(redirect_to("http://www.example.com/en/desk"))
    expect(member.reload.locale).to(eq("ru"))
  end

  it "does not link a Google account to the member" do
    sign_in(admin)
    post(admin_impersonate_path(member))

    get("/auth/google_oauth2/callback")

    expect(flash[:alert]).to(eq(I18n.t("admin.impersonation_read_only", locale: :ru)))
    expect(member.reload.google_uid).to(be_nil)
    in_locale(:ru) { get("/desk") }
    expect(response.body).to(include(I18n.t("admin.impersonation_stop", locale: :ru)))
  end

  it "refuses to impersonate yourself" do
    sign_in(admin)

    post(admin_impersonate_path(admin))

    expect(response).to(redirect_to(admin_users_path))
    expect(flash[:alert]).to(eq(I18n.t("admin.impersonate_self")))
  end

  it "is closed to non-admins" do
    sign_in(create(:user))

    post(admin_impersonate_path(member))

    expect(response).to(redirect_to(root_path))
    get("/desk")
    expect(response.body).not_to(include(I18n.t("admin.impersonation_stop")))
  end
end
