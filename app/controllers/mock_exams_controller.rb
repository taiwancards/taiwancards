# frozen_string_literal: true

class MockExamsController < ApplicationController
  allow_unauthenticated_access

  def index
  end

  def reading
    @paper = MockExam::Reading.build(band: band_param(MockExam::Reading), seed: seed_param)
  end

  def grade
    @paper = MockExam::Reading.build(band: band_param(MockExam::Reading), seed: seed_param)
    @results = results_for(@paper)
    @score = @results.count { |row| row[:correct] }
  end

  def pictures
    @paper = MockExam::Pictures.build(band: band_param(MockExam::Pictures), seed: seed_param)
  end

  def grade_pictures
    @paper = MockExam::Pictures.build(band: band_param(MockExam::Pictures), seed: seed_param)
    @results = results_for(@paper)
    @score = @results.count { |row| row[:correct] }
  end

  def listening
    @paper = MockExam::Listening.build(band: band_param(MockExam::Listening), seed: seed_param)
  end

  def grade_listening
    @paper = MockExam::Listening.build(band: band_param(MockExam::Listening), seed: seed_param)
    @results = results_for(@paper)
    @score = @results.count { |row| row[:correct] }
  end

  private

  def results_for(paper)
    allowed = paper.questions.map { |question| question.number.to_s }
    answers = params.fetch(:answers, {}).permit(*allowed).to_h
    paper.questions.map do |question|
      given = answers[question.number.to_s]&.to_i
      {question:, given:, correct: given == question.answer}
    end
  end

  def band_param(service)
    params[:band].presence_in(service.bands) || service.bands.first
  end

  def seed_param
    seed = params[:seed].to_i
    seed.positive? ? seed : SecureRandom.random_number(1_000_000) + 1
  end
end
