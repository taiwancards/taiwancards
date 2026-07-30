# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :require_admin

    def index
      @users = User.order(:email)
    end

    def update
      user = User.find(params[:id])
      if user == current_user && demoting?
        return redirect_to(admin_users_path, alert: t("admin.demote_self"))
      end

      return redirect_to(admin_users_path, alert: t("admin.save_failed")) unless user.update(user_params)

      redirect_to(admin_users_path, notice: t("admin.saved", email: user.display_name))
    end

    def destroy
      user = User.find(params[:id])
      return redirect_to(admin_users_path, alert: t("admin.delete_self")) if user == current_user

      email = user.display_name
      user.destroy!
      redirect_to(admin_users_path, notice: t("admin.deleted", email:))
    end

    private

    def user_params = params.expect(user: %i[admin restricted_content])

    def demoting? = user_params.key?(:admin) && !ActiveModel::Type::Boolean.new.cast(user_params[:admin])
  end
end
