# frozen_string_literal: true

class GradedCompletion < ApplicationRecord
  belongs_to :user

  validates :text_id, presence: true
  validates :score, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :total, numericality: {greater_than: 0}, allow_nil: true

  scope :owned_by, -> (user) { where(user:) }

  def self.record(user:, text_id:, score: nil, total: nil)
    row = create_or_find_by!(user:, text_id:) { |fresh| fresh.completed_at = Time.current }
    row.keep_best(score, total)
    row
  end

  def keep_best(score, total)
    return unless total.to_i.positive?
    return if quizzed? && score.to_i < self.score()

    update!(score: score.to_i.clamp(0, total.to_i), total: total.to_i)
  end

  def quizzed? = total.to_i.positive?
end
