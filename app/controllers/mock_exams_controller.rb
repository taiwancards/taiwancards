# frozen_string_literal: true

class MockExamsController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable only: %i[index]

  def index
  end

  def show
    @sheet = sheet
  end

  def grade
    @sheet = sheet
    @given = given_for(@sheet)
    @score = @sheet.slots.count { |slot| @given[slot.number] == slot.question.answer }
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

  def sheet
    MockExam::Paper.build(level: level_param, seed: seed_param)
  end

  def level_param
    MockExam::Bank.find(params[:level]) || MockExam::Bank.levels.first
  end

  def given_for(sheet)
    allowed = sheet.slots.map { |slot| slot.number.to_s }
    answers = params.fetch(:answers, {}).permit(*allowed).to_h
    answers.to_h { |number, index| [number.to_i, index.presence&.to_i] }
  end

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
