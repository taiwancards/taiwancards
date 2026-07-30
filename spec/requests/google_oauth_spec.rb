# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Google OAuth", :no_auth do
  before { OmniAuth.config.test_mode = true }

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  def mock_google(email:, uid:, name: "Den")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid:,
      info: {email:, name:},
      credentials: {token: "access-token", refresh_token: "refresh-token", expires_at: 2.hours.from_now.to_i}
    )
  end

  it "signs in via Google and creates a verified account" do
    mock_google(email: "brand-new@gmail.com", uid: "guid-1")
    get("/auth/google_oauth2/callback")

    expect(response).to(redirect_to(onboarding_start_path))
    user = User.find_by(google_uid: "guid-1")
    expect(user).to(be_present)
    expect(user.verified?).to(be(true))
    expect(user.google_refresh_token).to(eq("refresh-token"))
  end

  it "attaches Google to an existing account pre-linked by google_email" do
    target = create(:user, google_email: "new.learner@example.com")
    mock_google(email: "new.learner@example.com", uid: "guid-2")

    get("/auth/google_oauth2/callback")

    expect(User.find_by(google_uid: "guid-2")).to(eq(target))
  end

  it "links Google to the currently logged-in account" do
    user = sign_in(create(:user))
    mock_google(email: "someone@gmail.com", uid: "guid-3")

    get("/auth/google_oauth2/callback")

    expect(response).to(redirect_to(profile_path))
    expect(user.reload.google_uid).to(eq("guid-3"))
  end

  it "redirects to login instead of 500 when saving the Google account raises" do
    allow(User).to(receive(:for_google).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key")))
    mock_google(email: "racy@gmail.com", uid: "guid-4")

    get("/auth/google_oauth2/callback")

    expect(response).to(redirect_to(login_path))
  end
end
