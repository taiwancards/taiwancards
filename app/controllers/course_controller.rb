# frozen_string_literal: true

class CourseController < ApplicationController
  EXAM_PREFIX = "exam:"

  before_action :set_lesson, only: %i[show complete deck]
  before_action :set_stage, only: %i[exam complete_exam]

  def index
    @stages = Huayu::CourseLessons.stages
    @by_stage = Huayu::CourseLessons.by_stage
    @progress = progress
    @completions = progress.completions
    @resume = Huayu::CourseLessons.lessons.find { |lesson| @completions[lesson.slug].nil? }
    @slice = progress.slice_for(@resume&.stage || @stages.last&.slug)
  end

  def show
    @lines = annotated_lines
    @known_ids = known_lexeme_ids(@lines)
    @entries = vocabulary_entries
    @grammar = @lesson.grammar.filter_map { |ref| [ref, ref.lesson] if ref.lesson }
    @completion = progress.completions[@lesson.slug]
    @slice = progress.slice_for(@lesson.stage)
    @previous, @next = Huayu::CourseLessons.neighbours(@lesson)
  end

  def progress_report
    @progress = progress
    @pace = progress.pace
    @finish_by = finish_dates
    @finish_all = @pace&.finish_by(remaining_lessons)
    render("progress")
  end

  def exam
    @slice = progress.slice_for(@stage.slug)
    @completion = progress.completions[exam_slug]
    @lessons = Huayu::CourseLessons.by_stage[@stage.slug].to_a
  end

  def complete
    total = @lesson.exercises.size
    CourseCompletion.record(user: current_user, slug: @lesson.slug, score: params[:score].to_i.clamp(0, total), total:)
    redirect_to(course_lesson_path(@lesson), notice: t("course.saved"))
  end

  def complete_exam
    total = @stage.exam.size
    CourseCompletion.record(user: current_user, slug: exam_slug, score: params[:score].to_i.clamp(0, total), total:)
    redirect_to(course_exam_path(@stage), notice: t("course.saved"))
  end

  def deck
    desk = Collections::DeskBuilder.new(user: current_user).call(
      lexeme_ids: vocabulary_entries.values.map(&:id),
      name: deck_name
    )
    redirect_to(my_desk_path(desk), notice: t("desks.created"))
  end

  private

  def progress
    @progress_service ||= Huayu::CourseProgress.new(current_user)
  end

  def set_lesson
    @lesson = Huayu::CourseLessons.find(params[:slug])
    raise ActiveRecord::RecordNotFound if @lesson.nil?
  end

  def set_stage
    @stage = Huayu::CourseLessons.stage(params[:stage])
    raise ActiveRecord::RecordNotFound if @stage.nil? || @stage.exam.empty?
  end

  def exam_slug = "#{EXAM_PREFIX}#{@stage.slug}"

  def remaining_lessons
    Huayu::CourseLessons.lessons.count { |lesson| progress.completions[lesson.slug].nil? }
  end

  def finish_dates
    pace = progress.pace
    return {} if pace.nil?

    progress.slices.each_with_object({}) do |slice, dates|
      left = slice.lessons - slice.done
      next if left.zero?

      dates[slice.stage.slug] = pace.finish_by(lessons_before(slice) + left)
    end
  end

  def lessons_before(slice)
    progress
      .slices
      .take_while { |other| other.stage.slug != slice.stage.slug }
      .sum { |other| other.lessons - other.done }
  end

  def deck_name
    "#{t("course.deck_prefix", number: @lesson.number)} · #{@lesson.title_for(I18n.locale)}"
  end

  def annotated_lines
    tokens = Huayu::TextAnalyzer.new(locale: I18n.locale).analyze_lines(@lesson.lines.map(&:zh))
    @lesson.lines.each_with_index.map do |line, index|
      [line.zh, tokens[index] || [], line.translation(I18n.locale), line.who]
    end
  end

  def known_lexeme_ids(lines)
    ids = lines.flat_map { |_line, tokens, _translation, _who| tokens.filter_map { |token| token.lexeme&.id } }.uniq
    return Set.new if ids.empty?

    LexemeMemory.owned_by(current_user).active.where(lexeme_id: ids).pluck(:lexeme_id).to_set
  end

  KIND_PREFERENCE = %w[word collocation measure_word phrase character].freeze

  def vocabulary_entries
    @vocabulary_entries ||= begin
      texts = @lesson.words
      ranked = Lexeme
        .visible_to(current_user)
        .where(kind: KIND_PREFERENCE, text: texts)
        .group_by(&:text)
        .transform_values { |group| group.min_by { |lexeme| KIND_PREFERENCE.index(lexeme.kind) } }
      texts.index_with { |text| ranked[text] }.compact
    end
  end
end
