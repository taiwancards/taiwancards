# frozen_string_literal: true

class StudyPlan < ApplicationRecord
  LEVELS = %w[Novice1 Novice2 A1 A2 B1 B2 C].freeze

  belongs_to :user

  validates :target_level, presence: true, inclusion: {in: LEVELS}
  validates :target_date, presence: true
  validate :target_date_in_future

  private

  def target_date_in_future
    return if target_date.blank?

    errors.add(:target_date, :must_be_future) if target_date <= Date.current
  end
end
