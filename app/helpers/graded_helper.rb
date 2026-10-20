# frozen_string_literal: true

module GradedHelper
  FINISH_FORM = "graded-finish"

  def graded_finish_form = FINISH_FORM

  def graded_read_label(completion)
    return t("graded.read") unless completion.quizzed?

    t("graded.read_with_score", score: completion.score, total: completion.total)
  end
end
