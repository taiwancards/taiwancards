# frozen_string_literal: true

class DesksController < ApplicationController
  allow_unauthenticated_access only: :show
  publicly_cacheable only: :show

  def show
    return render("doors/home") unless authenticated?

    @entry = Onboarding::Entry.new(user: current_user)
    @home = Learn::Home.new(current_user)
    @next_step = Learn::NextStep.new(current_user).call
    @start_path = recommended_path
    @discovery = Learn::Discovery.new(current_user).call(except: @next_step.kind)
  end

  private

  def recommended_path
    return own_decks_path if @home.layout == "classes"
    return helpers.next_step_path(@next_step) if guiding_step?

    study_path(mode: "today")
  end

  def guiding_step? = [*Learn::NextStep::PHONETIC_STEPS, "starter"].include?(@next_step.kind)

  def own_decks_path
    @home.decks_count.zero? ? new_desk_path : study_path(mode: "decks")
  end
end
