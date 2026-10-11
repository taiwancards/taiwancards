# frozen_string_literal: true

module Newsletters
  module Tracking
    PURPOSE = :newsletter_click

    module_function

    def read(token) = verifier.verified(token.to_s, purpose: PURPOSE)

    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key("newsletter clicks"),
        url_safe: true,
        serializer: JSON
      )
    end

    def host = ActionMailer::Base.default_url_options[:host]

    def base
      options = ActionMailer::Base.default_url_options
      return if options[:host].blank?

      port = options[:port] ? ":#{options[:port]}" : ""
      "#{options.fetch(:protocol, "https")}://#{options[:host]}#{port}"
    end

    def absolute(url)
      text = url.to_s.strip
      return text if text.empty? || text.start_with?("mailto:") || base.nil?

      text.start_with?("/") ? "#{base}#{text}" : text
    end

    def site_host = Site.url && URI(Site.url).host

    def path_of(url)
      uri = URI(url)
      [uri.path.presence || "/", uri.query && "?#{uri.query}", uri.fragment && "##{uri.fragment}"].join
    end

    def visitable?(url)
      uri = URI(url.to_s)
      uri.is_a?(URI::HTTP) && uri.host.present? && [host, site_host].compact.include?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    def ours?(url, host = self.host())
      return false if host.blank?

      URI(url).then { |uri| uri.is_a?(URI::HTTP) && uri.host == host }
    rescue URI::InvalidURIError
      false
    end
  end
end
