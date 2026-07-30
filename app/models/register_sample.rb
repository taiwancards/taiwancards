# frozen_string_literal: true

class RegisterSample < ApplicationRecord
  belongs_to :content_source

  validates :text, presence: true
  validates :n, numericality: {greater_than_or_equal_to: 0}
end
