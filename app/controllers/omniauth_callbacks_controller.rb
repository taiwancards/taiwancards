# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  SIGN_IN = "sign_in"

  allow_unauthenticated_access

  def google_oauth2
    auth = request.env["omniauth.auth"]
    return redirect_to(login_path, alert: t("auth.oauth_failed")) if auth.blank?

    if authenticated? && !signing_in?
      current_user.link_google!(auth)
      return redirect_to(profile_backup_path, notice: t("auth.drive_connected")) if current_user.drive_linked?

      redirect_to(profile_path, notice: t("auth.google_linked"))
    else
      existing = User.exists?(google_uid: auth.uid) ||
        User.exists?(email: auth.info.email.to_s.downcase) ||
        User.exists?(google_email: auth.info.email.to_s.downcase)
      user = User.for_google(auth, locale: preferred_locale)
      user.update!(signup_from: signup_source) unless existing
      start_new_session_for(user)
      session[:fresh_account] = true unless existing
      welcome(user) unless existing
      redirect_to(take_return_path || desk_path, notice: t(existing ? "auth.signed_in" : "auth.signed_up"))
    end

  rescue => e
    Rails.logger.error("google_oauth2 callback failed: #{e.class}: #{e.message}")
    redirect_to(login_path, alert: t("auth.oauth_failed"))
  end

  def failure
    return redirect_to(login_path, alert: t("auth.oauth_failed")) unless authenticated?
    return redirect_to(origin_path, allow_other_host: false) unless params[:message] == "access_denied"
    return redirect_to(profile_backup_path, alert: t("auth.drive_declined")) if current_user.google_linked?

    redirect_to(profile_path)
  end

  private

  def preferred_locale
    header = request.env["HTTP_ACCEPT_LANGUAGE"].to_s
    wanted = header.split(",").map { |part| part.split(";").first.to_s.strip.downcase.split("-").first }
    available = I18n.available_locales.map(&:to_s)
    wanted.find { |code| available.include?(code) } || I18n.default_locale.to_s
  end

  def signing_in? = request.env["omniauth.params"].to_h["intent"] == SIGN_IN

  def origin_path
    origin = params[:origin].to_s
    own_path?(origin) ? origin : desk_path
  end

  def welcome(user)
    Reminders::Dispatch.welcome(user)
  rescue => e
    Rails.logger.error("welcome email failed: #{e.class}: #{e.message}")
  end

  def signup_source
    path = session[:return_to].presence || referring_path
    path && Locales.strip(path.split("?").first).first(PageView::PATH_LIMIT)
  end
end
