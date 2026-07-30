# frozen_string_literal: true

class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    code = params[:code].to_s
    return redirect_back(fallback_location: root_path) unless I18n.available_locales.map(&:to_s).include?(code)

    cookies.permanent[:locale] = {value: code, same_site: :lax}
    current_user&.update_column(:locale, code) if authenticated?

    redirect_back(fallback_location: root_path)
  end
end
