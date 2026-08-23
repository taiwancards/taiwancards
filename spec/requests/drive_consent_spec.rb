# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Google Drive consent" do
  before { OmniAuth.config.test_mode = true }

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  def mock_google(scope:)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "drive-guid",
      info: {email: "learner@gmail.com", name: "Den"},
      credentials: {token: "access-token", refresh_token: "refresh-token", expires_at: 2.hours.from_now.to_i, scope:}
    )
  end

  def grant_drive
    @authenticated_user.update!(
      google_refresh_token: "refresh-token",
      google_scopes: "email profile #{User::DRIVE_SCOPE}"
    )
  end

  it "does not treat a plain sign-in as Drive consent" do
    mock_google(scope: "openid email profile")

    get("/auth/google_oauth2/callback")

    expect(@authenticated_user.reload.drive_linked?).to(be(false))
  end

  it "connects Drive and lands on the backup tab once the scope is granted" do
    mock_google(scope: "openid email profile #{User::DRIVE_SCOPE}")

    get("/auth/google_oauth2/callback")

    expect(response).to(redirect_to(profile_backup_path))
    expect(@authenticated_user.reload.drive_linked?).to(be(true))
  end

  it "keeps the Drive grant through a later sign-in that asks for basic scopes only" do
    mock_google(scope: "openid email profile #{User::DRIVE_SCOPE}")
    get("/auth/google_oauth2/callback")

    mock_google(scope: "openid email profile")
    get("/auth/google_oauth2/callback")

    expect(@authenticated_user.reload.drive_linked?).to(be(true))
  end

  it "offers the consent button instead of the backup buttons until Drive is granted" do
    get("/profile/backup")

    expect(response.body).to(include(I18n.t("auth.drive_connect")))
    expect(response.body).not_to(include(I18n.t("auth.drive_backup")))
  end

  it "shows the backup buttons once Drive is granted" do
    grant_drive

    get("/profile/backup")

    expect(response.body).to(include(I18n.t("auth.drive_backup")))
    expect(response.body).not_to(include(I18n.t("auth.drive_connect")))
  end

  it "refuses a Drive backup that was never consented to" do
    post("/profile/drive_backup")

    expect(response).to(redirect_to(profile_backup_path))
    expect(flash[:alert]).to(eq(I18n.t("auth.drive_needs_consent")))
  end

  it "sends a linked user who declined Drive back to the backup tab" do
    @authenticated_user.update!(google_uid: "drive-guid")

    get("/auth/failure?message=access_denied&strategy=google_oauth2")

    expect(response).to(redirect_to(profile_backup_path))
    expect(flash[:alert]).to(eq(I18n.t("auth.drive_declined")))
  end

  it "explains the Drive consent in both locales" do
    %i[en ru].each do |locale|
      expect(I18n.t("auth.drive_connect_hint", locale:)).to(be_present)
      expect(I18n.t("auth.drive_declined", locale:)).to(be_present)
      expect(I18n.t("auth.drive_needs_consent", locale:)).to(be_present)
    end
  end
end
