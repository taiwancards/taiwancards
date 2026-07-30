# frozen_string_literal: true

class LexemeReview < ApplicationRecord
  belongs_to :lexeme_memory
  belongs_to :lexeme
  belongs_to :user, optional: true

  enum :facet, {recognition: 0, production: 1, reading: 2, tone: 3, writing: 4, listening: 5}, prefix: :facet

  scope :owned_by, -> (user) { where(user:) }
end
