# frozen_string_literal: true

Rails.application.configure do
  origins = -> (*names) { names.filter_map { |name| ENV[name].presence&.chomp("/") }.uniq }
  hosts = -> (*names) do
    names
      .flat_map { |name| ENV[name].to_s.split(",") }
      .filter_map { |value| value.strip[%r{\Ahttps?://[^/?#]+}] }
      .uniq
  end

  assets = origins.call("ASSETS_BASE_URL")
  media = origins.call("MEDIA_BASE_URL", "ASSETS_BASE_URL")
  sign_in = [
    OmniAuth::Strategies::GoogleOauth2
      .default_options
      .dig("client_options", "authorize_url")
      .to_s[%r{\Ahttps?://[^/?#]+}]
  ].compact

  config.content_security_policy do |policy|
    policy.default_src(:self)
    policy.base_uri(:self)
    policy.object_src(:none)
    policy.frame_ancestors(:none)
    policy.form_action(:self, *sign_in)
    policy.script_src(:self)
    policy.style_src(:self, :unsafe_inline)
    policy.img_src(:self, :data, :blob)
    policy.font_src(:self, :data, *assets)
    policy.media_src(:self, :data, :blob, *media)
    policy.connect_src(:self, *assets)
  end

  config.content_security_policy_nonce_generator = -> (request) do
    request.session.id.to_s.presence || SecureRandom.base64(16)
  end

  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = ENV["CSP_REPORT_ONLY"].present?
end
