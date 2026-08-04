# frozen_string_literal: true

module PracticeHelper
  PART_ONWARD = {"intro" => "initials", "initials" => "finals", "finals" => "tricky"}.freeze

  Bundle = Data.define(:key, :symbols, :rows) do
    def practisable? = key != "compound"
  end

  def phonetics_bundles(rows, group)
    taken = []
    bundles = Huayu::ZhuyinTrainer.blocks_in(group).filter_map do |block|
      picked = rows.select { |row| block[:symbols].include?(row["zhuyin"]) }
      next if picked.empty?

      taken.concat(picked)
      Bundle.new(key: block[:key], symbols: block[:symbols], rows: picked)
    end

    rest = rows - taken
    bundles << Bundle.new(key: "compound", symbols: [], rows: rest) if rest.any?
    bundles
  end

  def trainer_next_target(group)
    case group
    when "initials"
      {label: t("zhuyin_trainer.onward.finals"), path: practice_zhuyin_path(part: "finals"), primary: true}
    when "finals"
      {label: t("zhuyin_trainer.onward.tricky"), path: practice_zhuyin_path(part: "tricky"), primary: true}
    else
      {label: t("zhuyin_trainer.onward.typing"), path: practice_typing_path, primary: true}
    end
  end

  def practice_target_for(part)
    case part
    when "initials", "finals"
      {label: t("practice.practice_now.cta"), path: zhuyin_training_path(group: part, from: part)}
    when "tricky"
      {label: t("practice.to_drill"), path: practice_drill_path(from: part)}
    end
  end

  def practice_return_links
    @practice_return_links ||= build_practice_return_links
  end

  def practice_forward_link = practice_return_links.first

  def practice_back_link = practice_return_links.last

  def build_practice_return_links
    origin = params[:from].to_s
    return [{label: t("tones.drill.back"), path: tones_path, primary: true}] if origin == "tones"
    return [] unless PracticeController::PHONETICS_PARTS.include?(origin)

    onward = PART_ONWARD[origin]
    links = []
    if onward
      links <<
        {
          label: t("practice.part_next", title: t("practice.parts.#{onward}")),
          path: practice_zhuyin_path(part: onward),
          primary: true
        }
    end

    links <<
      {
        label: t("practice.part_previous", title: t("practice.parts.#{origin}")),
        path: practice_zhuyin_path(part: origin),
        primary: links.empty?
      }
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
