# frozen_string_literal: true

class ExamsController < ApplicationController
  SLUG_PREFIX = "tocfl:"

  allow_unauthenticated_access only: %i[index show]
  publicly_cacheable only: %i[index show]
  before_action :set_paper, only: %i[show record]

  def index
    @papers = Huayu::TocflPapers.all.select { |paper| Huayu::TocflBundles.available?(paper.slug) }
    @by_band = @papers.group_by(&:band)
    @scores = recorded_scores
  end

  def show
    @bundle = Huayu::TocflBundles.find(@paper.slug)
    @best = current_user && CourseCompletion.owned_by(current_user).find_by(slug: completion_slug)
  end

  def record
    score = @paper.mark(submitted_answers)
    best = CourseCompletion.record(user: current_user, slug: completion_slug, score:, total: @paper.count)
    current_user.reach_door!("exam")
    render(json: {score:, total: @paper.count, best: best.score})
  end

  private

  def set_paper
    @paper = Huayu::TocflPapers.find(params[:slug])
    raise ActiveRecord::RecordNotFound unless @paper && Huayu::TocflBundles.available?(@paper.slug)
  end

  def completion_slug = "#{SLUG_PREFIX}#{@paper.slug}"

  def recorded_scores
    return {} if current_user.nil?

    CourseCompletion.owned_by(current_user).where("slug LIKE ?", "#{SLUG_PREFIX}%").index_by(&:slug)
  end

  def submitted_answers
    allowed = @paper.numbers.map(&:to_s)
    raw = params.fetch(:answers, {}).permit(*allowed).to_h
    raw.to_h { |number, letter| [number.to_i, Huayu::TocflPapers::LETTERS.include?(letter) ? letter : nil] }
  end
end
