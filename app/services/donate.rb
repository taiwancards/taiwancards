# frozen_string_literal: true

module Donate
  module_function

  def script_url = ENV["DONATE_SCRIPT_URL"].presence

  def slug = ENV["DONATE_SLUG"].presence

  def offered? = script_url.present? && slug.present?
end
