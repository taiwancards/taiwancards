# frozen_string_literal: true

module Intro
  class Runner
    View = Data.define(:mode, :step, :position, :length, :chapter) do
      def blocking? = mode == :essential

      def skippable? = mode != :essential

      def last? = position >= length - 1

      def counter = "#{position + 1} / #{length}"
    end

    def initialize(user:, session:)
      @user = user
      @session = session
    end

    def call
      essential || chapter || whats_new
    end

    def chapter_steps
      chapter_id = @session[:intro_chapter]
      return [] if chapter_id.blank?

      Map.chapter(chapter_id)&.steps || []
    end

    def chapter_position
      @session[:intro_chapter_step].to_i.clamp(0, [chapter_steps.length - 1, 0].max)
    end

    def open_chapter!(chapter)
      @session[:intro_chapter] = chapter.id
      @session[:intro_chapter_step] = 0
    end

    def close_chapter!(completed: false)
      finished = @session.delete(:intro_chapter)
      @session.delete(:intro_chapter_step)
      progress.complete_chapter!(finished) if completed && finished.present?
      finished
    end

    def advance!
      move(1)
    end

    def rewind!
      move(-1)
    end

    private

    def move(offset)
      view = call
      return nil if view.nil?

      case view.mode
      when :essential
        offset.positive? ? progress.advance! : progress.rewind!
      when :chapter
        step_chapter(view.position + offset)
      else
        step_news(view.position + offset)
      end
    end

    def step_chapter(index)
      return close_chapter!(completed: true) if index >= chapter_steps.length

      @session[:intro_chapter_step] = index.clamp(0, chapter_steps.length - 1)
    end

    def step_news(index)
      pending = progress.unseen
      if index >= pending.length
        @session.delete(:intro_news_step)
        return progress.acknowledge_new!
      end

      @session[:intro_news_step] = index.clamp(0, pending.length - 1)
    end

    def news_position
      pending = progress.unseen
      return 0 if pending.empty?

      @session[:intro_news_step].to_i.clamp(0, pending.length - 1)
    end

    def progress = @user.intro

    def essential
      return nil unless Intro.gated? && progress.required?

      step = progress.step
      return nil if step.nil?

      View.new(
        mode: :essential,
        step: step,
        position: progress.position,
        length: progress.length,
        chapter: nil
      )
    end

    def chapter
      steps = chapter_steps
      return nil if steps.empty?

      View.new(
        mode: :chapter,
        step: steps[chapter_position],
        position: chapter_position,
        length: steps.length,
        chapter: @session[:intro_chapter]
      )
    end

    def whats_new
      pending = progress.unseen
      return nil if pending.empty?

      position = news_position
      View.new(mode: :whats_new, step: pending[position], position:, length: pending.length, chapter: nil)
    end
  end
end
