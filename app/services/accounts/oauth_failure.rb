# frozen_string_literal: true

module Accounts
  class OauthFailure
    REASONS = %i[
      access_denied
      csrf_detected
      failed_to_connect
      invalid_credentials
      invalid_request
      invalid_response
      timeout
    ]
      .freeze

    FALLBACK = :oauth_failed

    def self.call(env) = new(env).call

    def initialize(env)
      @env = env
    end

    def call
      @env["omniauth.error.type"] = reason
      OmniAuth::FailureEndpoint.call(@env)
    end

    private

    def reason
      type = @env["omniauth.error.type"]

      REASONS.include?(type) ? type : FALLBACK
    end
  end
end
