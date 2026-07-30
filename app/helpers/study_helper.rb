# frozen_string_literal: true

module StudyHelper
  FACET_ICONS = {
    "recognition" => :characters,
    "production" => :words,
    "reading" => :speaker,
    "listening" => :speaker,
    "tone" => :speaker,
    "writing" => :pencil
  }.freeze

  def facet_icon(facet)
    FACET_ICONS.fetch(facet.to_s, :study)
  end

  def study_next_suggestion
    return nil unless current_user
    case Learn::NextStep.new(current_user).call.kind
    when "zhuyin"
      {label: t("study.up_next.zhuyin"), body: t("study.up_next.zhuyin_body"), path: practice_zhuyin_path}
    when "drill"
      {label: t("study.up_next.drill"), body: t("study.up_next.drill_body"), path: zhuyin_training_path}
    when "typing"
      {label: t("study.up_next.typing"), body: t("study.up_next.typing_body"), path: practice_typing_path}
    else
      {label: t("study.up_next.ahead"), body: t("study.up_next.ahead_body"), path: study_path(mode: "cram")}
    end
  end
end
