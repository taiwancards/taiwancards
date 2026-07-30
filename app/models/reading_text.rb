# frozen_string_literal: true

class ReadingText < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :collection, optional: true

  enum :kind, {article: 0, song: 1, news: 2, graded: 3}

  validates :title, presence: true
  validates :body, presence: true

  scope :unrestricted, -> { where(restricted: false) }
  scope :visible_to, -> (user) { user&.restricted_access? ? all : unrestricted }
  scope :visible, -> { visible_to(Current.user) }
  scope :recent, -> { order(created_at: :desc) }

  def lines
    synced = body_data["synced"]
    return synced.map { |row| row["line"].to_s } if synced.is_a?(Array) && synced.any?

    body.split("\n")
  end

  def changed_characters
    Array(body_data["changed_chars"])
  end

  def attribution
    body_data["attribution"].presence
  end
end
