# frozen_string_literal: true

module PracticeHelper
  def trainer_next_target(group)
    case group
    when "initials"
      {label: t("zhuyin_trainer.onward.finals"), path: practice_zhuyin_path(part: "finals")}
    when "finals"
      {label: t("zhuyin_trainer.onward.tricky"), path: practice_zhuyin_path(part: "tricky")}
    else
      {label: t("zhuyin_trainer.onward.typing"), path: practice_typing_path}
    end
  end

  def practice_target_for(part)
    case part
    when "initials"
      {label: t("practice.practice_now.cta"), path: zhuyin_training_path(group: "initials")}
    when "finals"
      {label: t("practice.practice_now.cta"), path: zhuyin_training_path(group: "finals")}
    when "tricky"
      {label: t("practice.to_drill"), path: practice_drill_path}
    end
  end

  def phon_palladius?
    I18n.locale == :ru
  end

  def phon_analogy(row)
    phon_localized(row)
  end

  def phon_anchor(row)
    phon_localized(row["anchor"])
  end

  def phon_note(row)
    value = row["note"]
    return value.to_s if value.is_a?(String)

    phon_localized(value)
  end

  IPA_PATTERN = /(\[[^\]\[]{1,40}\])/

  def phon_markup(text)
    return "" if text.blank?

    parts = text.to_s.split(IPA_PATTERN)
    safe_join(
      parts.map { |part|
        if part.match?(/\A\[.+\]\z/)
          tag.code(part, class: "rounded bg-muted px-1 font-mono text-[0.95em] text-foreground")
        else
          part
        end
      }
    )
  end

  def phon_localized(source)
    return "" if source.blank?

    (I18n.locale == :ru ? source["ru"] : source["en"]).presence || source["en"].to_s
  end

  def phon_example_gloss(example)
    return "" if example.blank?

    (I18n.locale == :ru ? example["ru"] : example["en"]).presence || example["en"]
  end

  def accuracy_pct(correct, total)
    return nil if total.to_i.zero?

    (correct.to_i * 100 / total.to_i)
  end

  def tone_name(number)
    t("practice.tone_names.#{number}")
  end
end
