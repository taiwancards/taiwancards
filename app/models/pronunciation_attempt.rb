# frozen_string_literal: true

class PronunciationAttempt < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :lexeme

  scope :owned_by, -> (user) { where(user:) }
end
