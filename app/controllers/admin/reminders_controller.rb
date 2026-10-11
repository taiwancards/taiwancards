# frozen_string_literal: true

module Admin
  class RemindersController < ApplicationController
    before_action :require_admin

    def index
      stats = Admin::ReminderStats.new
      @triggers = stats.triggers
      @deliveries = stats.recent.to_a
      @returned = stats.returned_ids(@deliveries)
      @opted_out = stats.opted_out
      @paused_at = Setting.instance.reminders_paused_at
    end

    def update
      paused = params[:paused] == "1"
      Setting.instance.pause_reminders!(paused)
      MailEvent.log(current_user, list: "reminders", event: paused ? "paused" : "resumed", source: "admin")
      redirect_to(admin_reminders_path, notice: t("admin.reminders.#{paused ? "paused" : "resumed"}"))
    end
  end
end
