# frozen_string_literal: true

class ExamsController < ApplicationController
  SLUG_PREFIX = "tocfl:"
  LETTERS = %w[A B C D E F].freeze

  before_action :require_restricted_access
  before_action :set_paper, only: %i[show grade paper transcript clip]

  def index
    @by_band = Huayu::TocflPapers.by_band
    @scores = CourseCompletion.owned_by(current_user).where("slug LIKE ?", "#{SLUG_PREFIX}%").index_by(&:slug)
  end

  def show
    @best = CourseCompletion.owned_by(current_user).find_by(slug: completion_slug)
  end

  def grade
    given = submitted_answers
    @results = @paper.numbers.map do |number|
      expected = @paper.answer(number)
      {number:, given: given[number], expected:, correct: given[number] == expected}
    end

    @score = @results.count { |row| row[:correct] }
    @best = CourseCompletion.record(user: current_user, slug: completion_slug, score: @score, total: @paper.count)
    render(:show)
  end

  def paper
    send_official(Huayu::TocflPapers.paper_file(@paper.paper), "application/pdf")
  end

  def transcript
    send_official(Huayu::TocflPapers.paper_file(@paper.transcript), "application/pdf")
  end

  def clip
    name = params[:name].to_s
    raise ActiveRecord::RecordNotFound unless @paper.clips.include?(name)

    send_official(Huayu::TocflPapers.clip_file(@paper.audio, name), "audio/mpeg")
  end

  private

  def set_paper
    @paper = Huayu::TocflPapers.find(params[:slug])
    raise ActiveRecord::RecordNotFound if @paper.nil?
  end

  def completion_slug = "#{SLUG_PREFIX}#{@paper.slug}"

  def send_official(path, type)
    raise ActiveRecord::RecordNotFound if path.nil?

    send_file(path, type:, disposition: "inline")
  end

  def submitted_answers
    allowed = @paper.numbers.map(&:to_s)
    raw = params.fetch(:answers, {}).permit(*allowed).to_h
    raw.to_h { |number, letter| [number.to_i, LETTERS.include?(letter) ? letter : nil] }
  end
end
