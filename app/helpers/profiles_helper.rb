# frozen_string_literal: true

module ProfilesHelper
  TABS = %w[show display level guide backup].freeze

  def profile_tab_path(tab)
    case tab
    when "display"
      profile_display_path
    when "level"
      profile_level_path
    when "guide"
      guide_path
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
      [t("progress.tabs.data"), progress_data_path]
    ]
  end

  def projection_label(value)
    return t("auth.projection_open") if value == User::PROJECTION_OPEN

    scale, level = value.split(":")
    return t("auth.projection_chars", name: Huayu::CharacterTiers::NAMES.fetch(level.to_i)) if scale == "chars"

    t("auth.projection_option", scale: t("auth.projection_scales.#{scale}"), level: scale_level_label(scale, level))
  end

  def projection_options
    User.projection_options.map { |value| [projection_label(value), value] }
  end

  def scale_level_label(scale, level)
    return level.to_s if scale == "tbcl"

    SentenceProfile::TOCFL_LEVELS[level.to_i - 1].to_s
  end
end
