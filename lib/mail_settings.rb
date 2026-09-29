# frozen_string_literal: true

module MailSettings
  DEFAULT_PORT = 587
  DEFAULT_DAILY_LIMIT = 100
  LOCAL_FROM_ADDRESS = "newsletter@example.com"

  module_function

  def smtp? = ENV["SMTP_ADDRESS"].present?

  def smtp
    {
      address: ENV["SMTP_ADDRESS"],
      port: integer("SMTP_PORT", DEFAULT_PORT),
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true,
      open_timeout: 10,
      read_timeout: 20
    }
  end

  def url_options(url)
    return {} if url.blank?

    uri = URI(url)
    {host: uri.host, port: (uri.port unless uri.port == uri.default_port), protocol: uri.scheme}.compact
  end

  def local_url = "http://localhost:#{integer("APP_PORT", 3000)}"

  def from_address = ENV["MAIL_FROM_ADDRESS"].presence || (LOCAL_FROM_ADDRESS if Rails.env.local?)

  def reply_to = ENV["MAIL_REPLY_TO"].presence || ENV["SUPPORT_EMAIL"].presence || from_address

  def daily_limit = integer("NEWSLETTER_DAILY_LIMIT", DEFAULT_DAILY_LIMIT)

  def ready? = Rails.env.local? || [ENV["SMTP_ADDRESS"], ENV["MAIL_FROM_ADDRESS"], ENV["APP_URL"]].all?(&:present?)

  def integer(name, default) = Integer(ENV[name].presence || default)
end
