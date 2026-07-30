# frozen_string_literal: true

module Site
  PAGES = %w[/ /licenses /privacy /terms].freeze

  module_function

  def url = ENV["SITE_URL"].presence&.chomp("/")

  def published? = url.present? && !exporting?

  def page_url(path) = "#{url}#{path}"

  def exporting? = Thread.current[:site_exporting].present?

  def while_exporting
    Thread.current[:site_exporting] = true
    yield
  ensure
    Thread.current[:site_exporting] = nil
  end
end
