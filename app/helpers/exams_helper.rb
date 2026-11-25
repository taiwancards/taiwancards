# frozen_string_literal: true

module ExamsHelper
  def exam_level_name(name)
    case name.to_s
    when /\ALevel (\d)\z/
      t("exams.player.level_n", n: Regexp.last_match(1))
    when /\ANovice (\d)\z/
      t("exams.player.novice_n", n: Regexp.last_match(1))
    else
      name
    end
  end

  def exam_best_label(best, bundle)
    label = t("exams.best", score: best.score, total: best.total)
    scaled = bundle&.scaled(best.score)
    scaled ? "#{label} · #{scaled}/#{bundle.scale_max}" : label
  end

  def exam_plays(plays)
    case plays
    when 1
      t("exams.plays_once")
    when 2
      t("exams.plays_twice")
    else
      t("exams.plays_many", count: plays)
    end
  end

  BARE_PART_TITLE = /\A第[一二三四五六七八九十]+部分(?:\s*Part\s+\w+)?\z/i

  def exam_part_title(title) = title.to_s.strip.match?(BARE_PART_TITLE) ? nil : title

  def exam_part_line(part, listening:)
    line = [t("exams.player.part", n: part.id), exam_part_title(part.title), t("exams.questions", count: part.count)].compact.join(
      " · "
    )
    listening ? "#{line} · #{exam_plays(part.plays)}" : line
  end
end
