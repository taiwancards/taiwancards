# frozen_string_literal: true

module Donate
  HOST = "https://buymeacoffee.com"

  module_function

  def slug = ENV["DONATE_SLUG"].presence

  def url = slug && "#{HOST}/#{slug}"

  def offered? = url.present?
end
