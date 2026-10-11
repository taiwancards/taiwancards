# frozen_string_literal: true

class GoalsController < ApplicationController
  def update
    goal = params[:goal].to_s.presence_in(User::GOALS)
    return redirect_to(referring_path || desk_path) if goal.nil?

    current_user.update!(goal:)
    redirect_to(referring_path || desk_path, notice: t("goals.saved", goal: t("goals.options.#{goal}.title")))
  end
end
