# frozen_string_literal: true

Rails.application.config.middleware.use(OmniAuth::Builder) do
  provider(
    :google_oauth2,
    ENV["GOOGLE_OAUTH_CLIENT_ID"],
    ENV["GOOGLE_OAUTH_CLIENT_SECRET"],
    scope: "email,profile",
    access_type: "online"
  )
end

OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.on_failure = -> (env) { Accounts::OauthFailure.call(env) }
OmniAuth.config.logger = Rails.logger
