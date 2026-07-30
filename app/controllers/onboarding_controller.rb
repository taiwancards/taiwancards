# frozen_string_literal: true

class OnboardingController < ApplicationController
  PLACEMENT_LEVELS = %w[characters experienced].freeze

  def show
    redirect_to(roadmap_path) if current_user.start_chosen? && !params.key?(:again)
  end

  def create
    level = params[:start_level].to_s.presence_in(User::START_LEVELS)
    return redirect_to(onboarding_start_path, alert: t("onboarding.pick_one")) if level.nil?

    current_user.start_level = level
    current_user.level = "phonetics" if level == "phonetics"
    current_user.save!

    redirect_to(PLACEMENT_LEVELS.include?(level) ? placement_path : roadmap_path)
  end

  def path
    @path = Onboarding::Path.new(current_user)
  end

  def complete
    key = params[:step].to_s
    return redirect_to(roadmap_path) unless Onboarding::Path::STEPS.key?(key)

    if params[:undo].present?
      current_user.unmark_path_step!(key)
    else
      current_user.mark_path_step!(key)
    end

    redirect_to(roadmap_path)
  end
end
