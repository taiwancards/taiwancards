# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def google_oauth2
    auth = request.env["omniauth.auth"]
    return redirect_to(login_path, alert: t("auth.oauth_failed")) if auth.blank?

    if authenticated?
      current_user.link_google!(auth)
      redirect_to(profile_path, notice: t("auth.google_linked"))
    else
      existing = User.exists?(google_uid: auth.uid) ||
        User.exists?(email: auth.info.email.to_s.downcase) ||
        User.exists?(google_email: auth.info.email.to_s.downcase)
      user = User.for_google(auth, locale: preferred_locale)
      start_new_session_for(user)
      session[:fresh_account] = true unless existing
      redirect_to(after_google_path(existing:), notice: t(existing ? "auth.signed_in" : "auth.signed_up"))
    end

  rescue => e
    Rails.logger.error("google_oauth2 callback failed: #{e.class}: #{e.message}")
    redirect_to(login_path, alert: t("auth.oauth_failed"))
  end

  def failure
    redirect_to(login_path, alert: t("auth.oauth_failed"))
  end

  private

  def preferred_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    wanted = header.split(",").map { |part| part.split(";").first.to_s.strip.downcase.split("-").first }
    available = I18n.available_locales.map(&:to_s)
    wanted.find { |code| available.include?(code) } || I18n.default_locale.to_s
  end

  def after_google_path(existing:)
    take_return_path || (existing ? desk_path : onboarding_start_path)
  end
end
