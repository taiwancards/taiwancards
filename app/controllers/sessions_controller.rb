# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new]

  def new
  end

  def destroy
    terminate_session
    redirect_to(login_path, notice: t("auth.signed_out"))
  end
end
