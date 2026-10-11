# frozen_string_literal: true

module SetupHelper
  def setup_tasks
    return [] if current_user.nil? || current_user.start_chosen?

    [{label: t("setup.level"), path: onboarding_start_path}]
  end
end
