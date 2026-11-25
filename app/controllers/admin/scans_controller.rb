# frozen_string_literal: true

module Admin
  class ScansController < ApplicationController
    include ScanKeyGuard

    def index
      Scan.purge_expired unless impersonating?
      @days = params[:days].to_i.presence_in(Admin::ScanUsage::WINDOWS) || Admin::ScanUsage::WINDOWS.first
      @usage = Admin::ScanUsage.new(days: @days)
    end

    def reopen
      count = Scans::Incidents.reopen
      redirect_to(admin_scans_path, notice: t("scan.admin.key.reopened", count:), status: :see_other)
    end
  end
end
