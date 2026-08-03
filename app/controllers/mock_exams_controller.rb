# frozen_string_literal: true

class MockExamsController < ApplicationController
  allow_unauthenticated_access

  def index
  end

  def reading
    @paper = MockExam::Reading.build(band: band_param, seed: seed_param)
  end

  def grade
    @paper = MockExam::Reading.build(band: band_param, seed: seed_param)
    allowed = @paper.questions.map { |question| question.number.to_s }
    answers = params.fetch(:answers, {}).permit(*allowed).to_h
    @results = @paper.questions.map do |question|
      given = answers[question.number.to_s]&.to_i
      {question:, given:, correct: given == question.answer}
    end

    @score = @results.count { |row| row[:correct] }
  end

  private

  def band_param
    params[:band].presence_in(MockExam::Reading.bands) || "novice"
  end

  def seed_param
    seed = params[:seed].to_i
    seed.positive? ? seed : SecureRandom.random_number(1_000_000) + 1
  end
end
