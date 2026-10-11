# frozen_string_literal: true

class OnboardingController < ApplicationController
  def show
  end

  def create
    start = Onboarding::Start.new(current_user, goal: params[:goal], level: params[:level], known: params[:known])
    return redirect_to(origin || onboarding_start_path, alert: t("onboarding.pick_one")) unless start.valid?

    start.call
    redirect_to(after_start_path(start))
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

  private

  def after_start_path(start)
    return origin if origin && !home?(origin)
    return placement_path if start.placement?

    desk_path
  end

  def origin
    return @origin if defined?(@origin)

    back = referring_path
    @origin = back && !Locales.strip(back).start_with?(Locales.strip(onboarding_start_path)) ? back : nil
  end

  def home?(path) = [root_path, desk_path].map { |home| Locales.strip(home) }.include?(
    Locales.strip(path.split("?").first)
  )
end
