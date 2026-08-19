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
      essential || chapter
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

    def jump_to!(id)
      index = chapter_steps.index { |step| step.id == id }
      return advance! if index.nil?

      @session[:intro_chapter_step] = index
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
      else
        step_chapter(view.position + offset)
      end
    end

    def step_chapter(index)
      return close_chapter!(completed: true) if index >= chapter_steps.length

      @session[:intro_chapter_step] = index.clamp(0, chapter_steps.length - 1)
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
  end
end
