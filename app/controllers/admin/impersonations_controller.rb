# frozen_string_literal: true

module Admin
  class ImpersonationsController < ApplicationController
    before_action :require_true_admin

    def create
      target = User.find(params[:user_id])
      return redirect_to(admin_users_path, alert: t("admin.impersonate_self")) if target == true_user

      session[:impersonated_user_id] = target.id
      redirect_to(root_path, notice: t("admin.impersonating", email: target.email))
    end

    def destroy
      session.delete(:impersonated_user_id)
      redirect_to(admin_users_path, notice: t("admin.impersonation_stopped"))
    end

    private

    def require_true_admin
      return if true_user&.admin?

      redirect_to(root_path, alert: t("access.admin_denied"))
    end
  end
end
