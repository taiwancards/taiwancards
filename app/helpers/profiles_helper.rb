# frozen_string_literal: true

module ProfilesHelper
  TABS = %w[show display level backup].freeze

  def profile_tab_path(tab)
    case tab
    when "display"
      profile_display_path
    when "level"
      profile_level_path
    when "backup"
      profile_backup_path
    else
      profile_path
    end
  end

  def profile_tabs
    TABS.map { |tab| [t("auth.tabs.#{tab}"), profile_tab_path(tab)] }
  end

  def progress_tabs
    [
      [t("progress.tabs.summary"), progress_path],
      [t("progress.tabs.history"), progress_history_path],
      [t("progress.tabs.data"), progress_data_path(locale: nil)]
    ]
  end
end
