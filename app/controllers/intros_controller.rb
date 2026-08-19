# frozen_string_literal: true

class IntrosController < ApplicationController
  def show
    @blocks = Intro::Highlights.fetch
    @running = intro_progress&.required?
    @level_chosen = current_user.start_chosen?
    intro_progress.finish! if @running
  end

  def start
    remember_return_path(referring_path)
    redirect_to(here(intro_progress.start!&.path.presence || session[:return_to] || desk_path))
  end

  def pause
    intro_progress.pause!
    redirect_back(fallback_location: desk_path)
  end

  def advance
    landed = params[:step].to_s.presence
    walking_chapter = runner.call&.mode == :chapter
    landed ? runner.jump_to!(landed) : runner.advance!
    return head(:no_content) if request.xhr?
    return redirect_to(here(guide_path)) if walking_chapter && runner.call.nil?

    back_to_step
  end

  def rewind
    runner.rewind!
    back_to_step
  end

  def chapter
    chapter = Intro::Map.chapter(params[:id])
    return redirect_back(fallback_location: guide_path) if chapter.nil?

    runner.open_chapter!(chapter)
    redirect_to(here(chapter.steps.first&.path || guide_path))
  end

  def close_chapter
    runner.close_chapter!(completed: params[:completed].present?)
    redirect_to(guide_path)
  end

  private

  def runner
    @runner ||= Intro::Runner.new(user: current_user, session: session)
  end

  def back_to_step
    redirect_to(here(runner.call&.step&.path.presence || after_intro_path))
  end

  def after_intro_path
    stored = take_return_path
    return stored if stored.present? && current_user.start_chosen?
    return onboarding_start_path unless current_user.start_chosen?

    desk_path
  end

  def here(path) = Locales.swap(path, I18n.locale)
end
