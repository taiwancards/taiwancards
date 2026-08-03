# frozen_string_literal: true

class DesksController < ApplicationController
  def show
    @counts = lexeme_counts
    @next_step = Learn::NextStep.new(current_user).call
    @start_path = recommended_path
    @road = Learn::Road.new(current_user)
    @today = Study::TodayDesk.new(current_user).summary
    @mistake_count = Study::MistakeBook.new(current_user).count
  end

  private

  def lexeme_counts
    memories = LexemeMemory
      .active
      .owned_by(current_user)
      .joins(:lexeme)

    {
      on_desk: memories.distinct.count(:lexeme_id),
      due: memories.where.not(state: :unseen).where(due_at: ..Time.current).count,
      unseen: memories.where(state: :unseen).count
    }
  end

  def roadmap_first?
    !Onboarding::Path.new(current_user).complete? && current_user.level_grade.zero?
  end

  def recommended_path
    return roadmap_path if roadmap_first?

    case @next_step.kind
    when "zhuyin"
      practice_zhuyin_path
    when "drill"
      zhuyin_training_path
    when "typing"
      practice_typing_path
    else
      study_path(mode: "today")
    end
  end
end
