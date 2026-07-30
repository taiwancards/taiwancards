# frozen_string_literal: true

class LexemeMemory < ApplicationRecord
  belongs_to :lexeme
  belongs_to :user, optional: true
  has_many :lexeme_reviews, dependent: :destroy

  enum :facet, {recognition: 0, production: 1, reading: 2, tone: 3, writing: 4, listening: 5}, prefix: :facet
  enum :state, {unseen: 0, learning: 1, review: 2, relearning: 3}, prefix: :state

  scope :due, -> (at = Time.current) { where(due_at: ..at) }
  scope :active, -> { where.not(activated_at: nil) }
  scope :mature, -> { state_review.where(stability: 21..) }
  scope :owned_by, -> (user) { where(user:) }

  def due?(at = Time.current)
    due_at.present? && due_at <= at
  end
end
