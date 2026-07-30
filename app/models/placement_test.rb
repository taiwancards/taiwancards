# frozen_string_literal: true

class PlacementTest < ApplicationRecord
  belongs_to :user

  enum :status, {in_progress: 0, finished: 1, applied: 2}, prefix: :status

  def answered_count = Array(asked).length

  def record_answer(item, choice)
    correct = choice.to_s.presence && choice.to_i == item["answer"].to_i
    self.asked = Array(asked) +
      [
        {
          "id" => item["id"],
          "axis" => item["axis"],
          "grade" => item["grade"],
          "difficulty" => item["difficulty"],
          "correct" => correct.present?
        }
      ]
    correct.present?
  end

  def asked_lexeme_ids = Array(asked).filter_map { |row| row["id"].to_s.split("-").last&.to_i }

  def intake_result = Placement::Intake.call(intake.fetch("answers", {}), short: intake["short"].present?)

  def plan = Placement::Plan.new(intake_result, asked)

  def axis_grades = profile.fetch("axes", {})

  def split = profile["split"]

  def position = profile["position"].to_f

  def tolerance = profile["tolerance"].presence

  def diagnostics = profile.fetch("diagnostics", {})
end
