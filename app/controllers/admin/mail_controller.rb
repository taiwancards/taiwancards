# frozen_string_literal: true

module Admin
  class MailController < ApplicationController
    include Paginated

    before_action :require_admin

    PER_PAGE = 100

    def index
      @user = User.find_by(id: numeric_id(params[:user_id]))
      @list = params[:list].presence_in(MailEvent::LISTS)
      @event = params[:event].presence_in(MailEvent::EVENTS)
      @query = params[:q].to_s.strip.downcase.first(100)

      scope = filtered(MailEvent.all)
      @totals = scope.group(:event).count
      @subscribed = User::MAILING_COLUMNS.transform_values { |column| User.where(column => nil).count }
      @paused_at = Setting.instance.reminders_paused_at
      events, = paginate(scope.includes(:user).recent, per_page: PER_PAGE, total: @totals.values.sum)
      @events = events.to_a
    end

    private

    def filtered(scope)
      scope = scope.where(user: @user) if @user
      scope = scope.where(list: @list) if @list
      scope = scope.where(event: @event) if @event
      scope = scope.where("mail_events.email LIKE ?", "%#{MailEvent.sanitize_sql_like(@query)}%") if @query.present?
      scope
    end
  end
end
