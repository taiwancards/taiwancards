# frozen_string_literal: true

module MailLanding
  extend ActiveSupport::Concern

  included do
    allow_unauthenticated_access
    before_action :keep_private
  end

  private

  def any_browser? = true

  def speak_to(user)
    I18n.locale = user.locale if user && I18n.available_locales.map(&:to_s).include?(user.locale)
  end

  def keep_private
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "same-origin"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
