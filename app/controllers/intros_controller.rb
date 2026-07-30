# frozen_string_literal: true

class IntrosController < ApplicationController
  def advance
    runner.advance!
    back_to_step
  end

  def rewind
    runner.rewind!
    back_to_step
  end

  def language
    current_user.update!(locale: params[:code])
    cookies.permanent[:locale] = params[:code]
    runner.advance!
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
    redirect_to(chapter.steps.first&.path || guide_path)
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
    redirect_to(runner.call&.step&.path.presence || after_intro_path)
  end

  def after_intro_path
    current_user.intro_done? ? guide_path : desk_path
  end
end
