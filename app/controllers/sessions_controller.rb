# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new]

  def new
    remember_return_path(referring_path) if session[:return_to].blank? && !flash[:signed_out]
  end

  def destroy
    terminate_session
    session.delete(:return_to)
    redirect_to(login_path, notice: t("auth.signed_out"), flash: {signed_out: true})
  end
end
