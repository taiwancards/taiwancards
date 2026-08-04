# frozen_string_literal: true

class IntrosController < ApplicationController
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
    landed ? runner.jump_to!(landed) : runner.advance!
    return head(:no_content) if request.xhr?

    back_to_step
  end

  def rewind
    runner.rewind!
    back_to_step
  end

  def seen
    session.delete(:intro_news_step)
    intro_progress.acknowledge_new!
    redirect_back(fallback_location: desk_path)
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
    current_user.intro_done? ? guide_path : (stored || desk_path)
  end

  def here(path) = Locales.swap(path, I18n.locale)
end
