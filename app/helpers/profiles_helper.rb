# frozen_string_literal: true

module ProfilesHelper
  TABS = %w[show display backup].freeze

  def profile_tab_path(tab)
    case tab
    when "display"
      profile_display_path
    when "backup"
      profile_backup_path
    else
      profile_path
    end
  end

  def profile_tabs
    TABS.map { |tab| [t("auth.tabs.#{tab}"), profile_tab_path(tab)] }
  end

  def level_change_notes(user)
    current = user.level_grade
    User::LEVELS.filter_map do |value|
      grade = Integer(value, exception: false) || 0
      next if grade == current

      upcoming = grade + 1
      upcoming = upcoming > User::LEVELS.last.to_i ? t("auth.level_change.beyond") : level_label(upcoming.to_s)
      direction = grade > current ? "up" : "down"
      [value, t("auth.level_change.#{direction}", level: level_label(value), next: upcoming)]
    end
  end

  def progress_tabs
    [
      [t("progress.tabs.summary"), progress_path],
      [t("progress.tabs.history"), progress_history_path],
      [t("progress.tabs.data"), progress_data_path]
    ]
  end
end
