# frozen_string_literal: true

module GoalsHelper
  GOAL_ICONS = {"tocfl" => :stats, "classes" => :decks, "guided" => :study}.freeze

  def goal_icon(goal) = GOAL_ICONS.fetch(goal.to_s, :study)

  GOAL_PICKER_SKIPS = %w[onboarding study_sessions starter_lessons].freeze

  def goal_picker?
    authenticated? && !impersonating? && !current_user.goal_chosen? && GOAL_PICKER_SKIPS.exclude?(controller_path)
  end
end
