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
    get(practice_path(from: "initials"))
    expect(response).to(redirect_to(login_path))

    google!

    expect(response).to(redirect_to(practice_path(from: "initials")))
  end

  it "asks a newcomer for the mode on the very page they came for, then keeps them there" do
    page = practice_path(from: "initials")
    get(page)
    google!
    follow_redirect!

    expect(response.body).to(include("id=\"goal-picker\""))

    post(
      onboarding_start_path,
      params: {goal: "guided", level: "unknown"},
      headers: {"HTTP_REFERER" => "http://www.example.com#{page}"}
    )

    expect(response).to(redirect_to("/en#{page}"))
  end

  it "brings an existing account back to the page it signed in from" do
    get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/menu"})

    google!(existing: true)

    expect(response).to(redirect_to("/en/menu"))
  end

  it "does not send the next account back to the page the last one signed out from" do
    sign_in(user)
    delete("/en/logout", headers: {"HTTP_REFERER" => "http://www.example.com/en/profile"})
    follow_redirect!(headers: {"HTTP_REFERER" => "http://www.example.com/en/profile"})

    google!

    expect(response).to(redirect_to(desk_path))
  end

  it "opens the desk for a brand new account, where the start dialog asks for its mode and level" do
    get("/login")

    google!

    expect(response).to(redirect_to(desk_path))
    follow_redirect!
    expect(response.body).to(include("id=\"goal-picker\"", "data-controller=\"modal-lock\""))
  end

  it "opens the desk for a returning account with nowhere to go back to" do
    get("/login")

    google!(existing: true)

    expect(response).to(redirect_to(desk_path))
  end

  it "refuses a return address that is not ours" do
    get("/login", headers: {"HTTP_REFERER" => "https://evil.example.org/steal"})

    google!

    expect(response).to(redirect_to(desk_path))
  end

  it "never sends anyone back to the sign-in page itself" do
    get("/login", headers: {"HTTP_REFERER" => "http://www.example.com/login"})

    google!

    expect(response).to(redirect_to(desk_path))
  end
end
