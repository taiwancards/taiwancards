# frozen_string_literal: true

class SenseExample < ApplicationRecord
  belongs_to :lexeme_sense
  belongs_to :content_source
  belongs_to :lexeme, optional: true

  enum :kind, {sentence: 0, collocation: 1}

  validates :text, presence: true

  scope :ordered, -> { order(:position) }

  def self.visible_to(user)
    where(content_source: ContentSource.visible_to(user))
  end
end
