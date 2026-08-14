# frozen_string_literal: true

module CourseHelper
  REGISTER_STYLES = {
    "spoken" => "border-sky-500 text-sky-600",
    "written" => "border-violet-500 text-violet-600"
  }.freeze

  def course_register_chip(word)
    return nil unless word.marked?

    tag.span(
      t("course.registers.#{word.register}"),
      class: class_names("shrink-0 rounded-full border px-2 py-0.5 text-xs", REGISTER_STYLES[word.register])
    )
  end

  def course_stage_progress(lessons, completions)
    done = lessons.count { |lesson| completions.key?(lesson.slug) }
    [done, lessons.size]
  end

  def course_word_path(word, entries)
    entry = entries[word.zh]
    entry && lexeme_page_path(entry)
  end

  def course_lesson_number(lesson)
    t("course.lesson_number", number: lesson.number)
  end
end
