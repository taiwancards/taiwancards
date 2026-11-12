# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session rotation" do
  def stored_keys = session.to_h.keys - %w[session_id _csrf_token flash]

  def as_google(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "rotation-#{user.id}",
      info: {email: user.email, name: user.name},
      credentials: {token: "access-token", refresh_token: "refresh-token", expires_at: 2.hours.from_now.to_i}
    )
  end

  def arrive_from_google(user)
    as_google(user)
    get("/auth/google_oauth2/callback")
  end

  context("when a visitor signs in", :no_auth) do
    it "hands out a fresh session rather than promoting the one the visitor arrived with" do
      get("/writing")
      before = session.id.public_id

      arrive_from_google(create(:user))

      expect(session.id.public_id).not_to(eq(before))
    end

    it "still returns the visitor to the page they were sent away from" do
      get("/writing")

      arrive_from_google(create(:user))

      expect(response).to(redirect_to("/en/writing"))
    end
  end

  it "drops what the previous account kept in the session when another account signs in" do
    get("/writing")
    kept = stored_keys
    expect(kept).not_to(be_empty)

    as_google(create(:user))
    post("/auth/google_oauth2?intent=sign_in")
    follow_redirect!

    expect(session.to_h.keys & kept).to(be_empty)
  end

  it "clears everything the session held once the reader signs out" do
    get("/writing")
    kept = stored_keys
    expect(kept).not_to(be_empty)

    delete("/logout")

    expect(session.to_h.keys & kept).to(be_empty)
    expect(flash[:notice]).to(eq(I18n.t("auth.signed_out")))
  end
end
