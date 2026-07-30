# frozen_string_literal: true

class StudyPlansController < ApplicationController
  def show
    @plan = StudyPlan.find_by(user: current_user)
    @calculator = @plan && Study::PlanCalculator.new(@plan)
    @today = Study::TodayDesk.new(current_user).summary
  end

  def new
    @plan = StudyPlan.new(target_date: Date.current + 90)
  end

  def create
    @plan = StudyPlan.find_or_initialize_by(user: current_user)
    @plan.assign_attributes(plan_params)
    if @plan.save
      redirect_to(study_plan_path, notice: t("plan.saved"))
    else
      render(:new, status: :unprocessable_entity)
    end
  end

  private

  def plan_params
    params.expect(study_plan: %i[target_level target_date])
  end
end
