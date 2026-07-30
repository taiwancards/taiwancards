# frozen_string_literal: true

class LexemeSense < ApplicationRecord
  belongs_to :lexeme
  belongs_to :content_source, optional: true
  has_many(
    :examples,
    -> { order(:position) },
    class_name: "SenseExample",
    dependent: :destroy,
    inverse_of: :lexeme_sense
  )

  validates :position, presence: true, uniqueness: {scope: :lexeme_id}

  scope :ordered, -> { order(:position) }

  def self.visible_to(user)
    ids = ContentSource.visible_to(user).select(:id)
    where(content_source_id: nil).or(where(content_source_id: ids))
  end

  def meaning(locale)
    meanings[locale.to_s].presence || meanings["en"].presence
  end

  def number
    position + 1
  end
end
