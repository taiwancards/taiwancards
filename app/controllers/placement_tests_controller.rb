# frozen_string_literal: true

class PlacementTestsController < ApplicationController
  def show
    @test = current_test
    @item = @test.pending.presence if @test&.status_in_progress?
    @questions = Placement::Intake::QUESTIONS
  end

  def create
    current_test&.destroy
    @test = PlacementTest.create!(
      user: current_user,
      status: :in_progress,
      intake: {"answers" => intake_answers, "short" => params[:short].present?}
    )
    serve_next(@test)
    redirect_to(placement_path)
  end

  def answer
    @test = current_test
    return redirect_to(placement_path) unless @test&.status_in_progress?

    item = @test.pending
    return redirect_to(placement_path) if item.blank?

    @test.record_answer(item, params[:choice])
    serve_next(@test)
    redirect_to(placement_path)
  end

  def apply
    @test = current_test
    return redirect_to(placement_path) unless @test&.status_finished?

    grade = (params[:grade].presence&.to_i || @test.result_grade.to_i).clamp(0, Placement::Ability::MAX_GRADE)
    result = Placement::Seeder.new(current_user).call(grade)
    adopt(grade)
    @test.update!(status: :applied, result_grade: grade, seeded_count: result[:seeded])

    redirect_to(placement_path, notice: t("placement.applied", count: result[:seeded]))
  end

  private

  def intake_answers
    Placement::Intake::QUESTIONS.keys.index_with { |name| params.dig(:intake, name).to_s }
  end

  def current_test
    @current_test ||= PlacementTest.where(user: current_user).order(:created_at).last
  end

  def serve_next(test)
    plan = test.plan
    bank = Placement::ItemBank.new
    exhausted = []

    loop do
      step = plan.next_step(skip: exhausted)
      return finish(test, step.outcome) if step.finished

      item = bank.item_for(axis: step.axis, grade: step.grade, exclude_ids: test.asked_lexeme_ids)
      return test.update!(pending: item, current_grade: step.grade) if item

      exhausted << step.axis
    end
  end

  def finish(test, outcome)
    test.update!(
      status: :finished,
      result_grade: outcome.grade,
      current_grade: nil,
      pending: {},
      profile: {
        "axes" => outcome.axes,
        "position" => outcome.position,
        "error" => outcome.error,
        "tolerance" => outcome.tolerance,
        "split" => outcome.split,
        "diagnostics" => outcome.diagnostics
      }
    )
  end

  def adopt(grade)
    return if grade.zero?

    current_user.level = grade.to_s
    current_user.visibility_tolerance = @test.tolerance if @test.tolerance
    current_user.save!
  end
end
