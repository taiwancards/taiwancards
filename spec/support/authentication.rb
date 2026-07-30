# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in(user = nil)
    user ||= create(:user)
    reset!
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: user.google_uid.presence || "test-uid-#{user.id}",
      info: {email: user.email, name: user.name},
      credentials: {token: "access-token", refresh_token: "refresh-token", expires_at: 2.hours.from_now.to_i}
    )
    get("/auth/google_oauth2/callback")
    Current.user = user
    user
  end
end

RSpec.configure do |config|
  config.include(AuthenticationHelpers, type: :request)

  config.before(:each, type: :request) do |example|
    @authenticated_user = sign_in unless example.metadata[:no_auth]
  end

  config.after(:each) do
    Current.reset
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end
end
