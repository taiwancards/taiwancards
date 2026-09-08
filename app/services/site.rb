# frozen_string_literal: true

module Site
  module_function

  def url = ENV["SITE_URL"].presence&.chomp("/")

  def support_email = ENV["SUPPORT_EMAIL"].presence

  def published? = url.present? && !exporting?

  def page_url(path, locale = I18n.locale) = "#{url}/#{locale}#{path.chomp("/")}"

  def exporting? = Thread.current[:site_exporting].present?

  def while_exporting
    Thread.current[:site_exporting] = true
    yield
  ensure
    Thread.current[:site_exporting] = nil
  end
end
