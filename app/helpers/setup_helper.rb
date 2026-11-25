# frozen_string_literal: true

module SetupHelper
  def setup_tasks
    return [] if current_user.nil? || current_user.start_chosen?
    return [] if Onboarding::Entry.new(user: current_user).offer_setup?

    [{label: t("setup.level"), path: onboarding_start_path}]
  end
end
