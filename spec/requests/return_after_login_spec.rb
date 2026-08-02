# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Coming back to where the sign-in started", :no_auth do
  let(:user) { create(:user) }

  def google!(existing: false)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: existing ? (user.google_uid.presence || "uid-#{user.id}") : "uid-fresh",
      info: {email: existing ? user.email : "fresh@example.com", name: "Test"},
      credentials: {token: "t", refresh_token: "r", expires_at: 2.hours.from_now.to_i}
    )
    get("/auth/google_oauth2/callback")
  end

  it "sends a guest turned away from a page back to that page" do
    get(zhuyin_training_path(group: "initials", from: "initials"))
    expect(response).to(redirect_to(login_path))

    google!

    expect(response).to(redirect_to(zhuyin_training_path(group: "initials", from: "initials")))
  end

  it "brings an existing account back to the page it signed in from" do
    user.update!(prefs: user.prefs.merge("intro_stage" => "done"))
    get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/menu"})

    google!(existing: true)

    expect(response).to(redirect_to("/menu"))
  end

  it "asks a brand new account for its level when it came straight to the sign-in page" do
    get("/login")

    google!

    expect(response).to(redirect_to(onboarding_start_path))
  end

  it "opens the desk for a returning account with nowhere to go back to" do
    user.update!(prefs: user.prefs.merge("intro_stage" => "done"))
    get("/login")

    google!(existing: true)

    expect(response).to(redirect_to(desk_path))
  end

  it "refuses a return address that is not ours" do
    get("/login", headers: {"HTTP_REFERER" => "https://evil.example.org/steal"})

    google!

    expect(response).to(redirect_to(onboarding_start_path))
  end

  it "never sends anyone back to the sign-in page itself" do
    get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/login"})

    google!

    expect(response).to(redirect_to(onboarding_start_path))
  end
end
