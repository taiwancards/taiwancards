# frozen_string_literal: true

class SettingsController < ApplicationController
  def edit
    @settings = Setting.instance
  end

  def update
    settings = Setting.instance
    settings.update!(data: settings.data.merge(settings_params))
    redirect_to(edit_settings_path, notice: t("settings.updated"))
  end

  private

  def settings_params
    permitted = params.expect(setting: %i[desired_retention daily_new_limit learn_ahead_minutes])
    {
      "desired_retention" => permitted[:desired_retention].to_f.clamp(0.7, 0.99),
      "daily_new_limit" => permitted[:daily_new_limit].to_i.clamp(0, 500),
      "learn_ahead_minutes" => permitted[:learn_ahead_minutes].to_i.clamp(0, 120)
    }
  end
end
