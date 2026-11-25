# frozen_string_literal: true

module Admin
  class ScanModelsController < ApplicationController
    include ScanKeyGuard

    def create
      chosen = params[:model].presence
      outcome = Scans::Credentials.choose_model(chosen)
      message = t("scan.admin.model_choice.saved.#{outcome}", model: chosen || Scans::Settings.environment_model)
      flash[outcome == :ok ? :notice : :alert] = message
      redirect_to(admin_scans_path, status: :see_other)
    end
  end
end
