# frozen_string_literal: true

module NextStepHelper
  def next_step_path(step)
    case step.kind
    when "zhuyin"
      practice_zhuyin_path
    when "bridge", "drill"
      zhuyin_training_path
    when "typing"
      practice_typing_path
    when "starter"
      starter_lesson_path(step.subject)
    when "lesson"
      course_lesson_path(step.subject)
    when "graded"
      graded_path
    when "grammar"
      grammar_path(level: step.subject)
    when "decks"
      study_path(mode: "decks")
    when "practice"
      study_path(mode: "collection", collection_id: step.subject)
    when "add_words"
      new_desk_path
    else
      study_path(mode: "today")
    end
  end

  def next_step_title(step) = t("next_step.#{next_step_key(step)}.title")

  def next_step_body(step) = t("next_step.#{next_step_key(step)}.body")

  def desk_start_hint(step)
    key = [*Learn::NextStep::PHONETIC_STEPS, "starter"].include?(step.kind) ? next_step_key(step) : "study"
    t("desk.next_step.#{key}")
  end

  private

  def next_step_key(step) = step.kind == "bridge" ? "drill" : step.kind
end
