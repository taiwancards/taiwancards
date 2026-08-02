# frozen_string_literal: true

module Returning
  extend ActiveSupport::Concern

  private

  def remember_return_path(path)
    session[:return_to] = path if own_path?(path)
  end

  def take_return_path
    path = session.delete(:return_to)
    path if own_path?(path)
  end

  def referring_path
    uri = URI.parse(request.referer.to_s)
    return nil unless uri.host.nil? || uri.host == request.host

    [uri.path.presence, uri.query].compact.join("?").presence
  rescue URI::InvalidURIError
    nil
  end

  def own_path?(path)
    path.present? && path.start_with?("/") && !path.start_with?("//") && !path.start_with?(login_path)
  end
end
