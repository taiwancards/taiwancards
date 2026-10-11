# frozen_string_literal: true

class PageViewsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection
  skip_after_action :track_activity

  def create
    request.session_options[:skip] = true
    payload = JSON.parse(request.raw_post.presence || "{}")
    return head(:no_content) unless payload.is_a?(Hash) && known?(path = payload["path"].to_s.split("?").first.to_s)

    PageView.count!(
      path: "#{payload["site"] == true ? PageView::SITE : ""}#{Locales.strip(path)}",
      locale: Locales.prefix(path).to_s,
      referrer: payload["referrer"],
      host: request.host,
      user_agent: request.user_agent,
      country: request.headers["CF-IPCountry"]
    )
    head(:no_content)
  rescue JSON::ParserError
    head(:no_content)
  end

  private

  def any_browser? = true

  def known?(path)
    return false unless path.start_with?("/") && !path.start_with?("//") && path.length <= PageView::PATH_LIMIT

    Rails.application.routes.recognize_path(path).present?
  rescue ActionController::RoutingError
    false
  end
end
