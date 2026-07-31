# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    include Paginated

    before_action :require_admin

    PER_PAGE = 30
    EVENTS_PER_PAGE = 50
    SORTS = {
      "seen" => "last_seen_at DESC NULLS LAST, id DESC",
      "joined" => "created_at DESC",
      "email" => "email ASC"
    }.freeze

    def index
      @sort = params[:sort].presence_in(SORTS.keys) || SORTS.keys.first
      page, = paginate(User.order(Arel.sql(SORTS[@sort])), per_page: PER_PAGE)
      @users = page.to_a
      @stats = Admin::UserStats.new(@users)
    end

    def show
      @user = User.find(params[:id])
      @profile = Admin::UserProfile.new(@user)
      feed = @user.activity_events.recent
      events, = paginate(feed, per_page: EVENTS_PER_PAGE, total: @profile.counts[:events])
      @events = events.to_a
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
