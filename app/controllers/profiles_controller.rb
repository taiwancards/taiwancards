# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :set_user

  def show
  end

  def display
  end

  def level
  end

  def guide
  end

  def backup
    @memory_count = current_user.lexeme_memories.count
    @review_count = current_user.lexeme_reviews.count
  end

  def update
    tab = params[:tab].presence_in(ProfilesHelper::TABS) || "show"

    if current_user.update(profile_params)
      return head(:no_content) if params[:inline].present?

      redirect_to(helpers.profile_tab_path(tab), notice: t("auth.profile_saved"))
    else
      return head(:unprocessable_entity) if params[:inline].present?

      render(tab, status: :unprocessable_entity)
    end
  end

  def export
    data = Progress::Export.new(current_user).call
    send_data(
      JSON.pretty_generate(data),
      filename: "taiwancards-progress-#{Time.current.strftime("%Y%m%d")}.json",
      type: "application/json"
    )
  end

  def import
    file = params[:file]
    return redirect_to(profile_path, alert: t("auth.import_no_file")) if file.blank?

    json = JSON.parse(file.read)
    result = Progress::Import.new(current_user).call(json)
    redirect_to(profile_path, notice: t("auth.import_done", **result))
  rescue JSON::ParserError
    redirect_to(profile_path, alert: t("auth.import_bad"))
  end

  def reset
    current_user.lexeme_reviews.delete_all
    current_user.lexeme_memories.delete_all
    current_user.placement_tests.destroy_all
    current_user.study_plans.destroy_all
    PronunciationAttempt.owned_by(current_user).delete_all
    current_user.syllable_skills.delete_all
    current_user.update!(prefs: current_user.prefs.slice(*User::KEPT_ON_RESET))

    redirect_to(profile_path, notice: t("auth.reset_done"))
  end

  def drive_backup
    return redirect_to(profile_path, alert: t("auth.drive_needs_link")) unless current_user.google_linked?

    name = Progress::DriveBackup.new(current_user).save
    redirect_to(profile_path, notice: t("auth.drive_saved", name:))
  rescue Google::DriveClient::Error => e
    redirect_to(profile_path, alert: t("auth.drive_error", message: e.message))
  end

  def drive_restore
    return redirect_to(profile_path, alert: t("auth.drive_needs_link")) unless current_user.google_linked?

    result = Progress::DriveBackup.new(current_user).restore
    redirect_to(profile_path, notice: t("auth.import_done", **result))
  rescue Google::DriveClient::Error => e
    redirect_to(profile_path, alert: t("auth.drive_error", message: e.message))
  end

  private

  def set_user
    @user = current_user
  end

  def profile_params
    permitted = params.expect(
      user: [
        :name,
        :locale,
        :zhuyin_position,
        :text_direction,
        :level,
        :password,
        :password_confirmation,
        {mobile_tabs: []}
      ]
    )
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
    permitted
  end
end
