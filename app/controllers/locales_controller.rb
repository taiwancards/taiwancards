# frozen_string_literal: true

class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    code = params[:code].to_s
    return redirect_to(back_here(I18n.locale)) unless Locales.known?(code)

    cookies.permanent[:locale] = {value: code, same_site: :lax}
    current_user&.update_column(:locale, code) if authenticated?

    redirect_to(back_here(code))
  end

  private

  def back_here(code)
    Locales.swap(request.referer.presence || root_path(locale: code), code)
  end
end
