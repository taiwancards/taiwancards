# frozen_string_literal: true

module Site
  SUPPORT_EMAIL = "support@taiwancards.app"

  module_function

  def url = ENV["SITE_URL"].presence&.chomp("/")

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
