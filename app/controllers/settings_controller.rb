# frozen_string_literal: true

class SettingsController < ApplicationController
  def edit
    @preferences = Study::Preferences.for(current_user)
    @settings = @preferences.settings
  end

  def update
    overrides = Study::Preferences.sanitize(settings_params)
    current_user.write_prefs(Study::Preferences::PREFS_KEY => stored_overrides.merge(overrides))
    current_user.save!
    apply_installation_defaults(overrides) if current_user.admin? && params[:as_default].present?
    redirect_to(edit_settings_path, notice: t("settings.updated"))
  end

  def destroy
    current_user.write_prefs(Study::Preferences::PREFS_KEY => {})
    current_user.save!
    redirect_to(edit_settings_path, notice: t("settings.restored"))
  end

  private

  def stored_overrides
    current_user.prefs[Study::Preferences::PREFS_KEY] || {}
  end

  def settings_params
    params.expect(setting: Study::Preferences::KEYS.map(&:to_sym)).to_h
  end

  def apply_installation_defaults(overrides)
    settings = Setting.instance
    settings.update!(data: settings.data.merge(overrides))
  end
end
