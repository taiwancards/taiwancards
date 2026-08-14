# frozen_string_literal: true

class CourseCompletion < ApplicationRecord
  belongs_to :user

  validates :slug, presence: true

  scope :owned_by, -> (user) { where(user:) }
  scope :finished, -> { where.not(completed_at: nil) }

  def self.record(user:, slug:, score:, total:)
    row = find_or_initialize_by(user:, slug:)
    row.score = [row.score.to_i, score.to_i].max
    row.total = total.to_i
    row.completed_at ||= Time.current
    row.save!
    row
  end

  def ratio
    return 0.0 if total.to_i.zero?

    score.to_f / total
  end
end
