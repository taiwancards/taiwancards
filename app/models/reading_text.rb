# frozen_string_literal: true

class ReadingText < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :collection, optional: true

  enum :kind, {article: 0, song: 1, news: 2, graded: 3, story: 4}

  LIBRARY_KINDS = (kinds.keys - %w[story]).freeze
  LEARNER_LIMIT = Collections::TextPreview::MAX_CHARS

  validates :title, presence: true
  validates :body, presence: true
  validates :body, length: {maximum: LEARNER_LIMIT}, if: :user_id?

  scope :unrestricted, -> { where(restricted: false) }
  scope :visible_to, -> (user) { (user&.restricted_access? ? all : unrestricted).where(user_id: [nil, user&.id].uniq) }
  scope :owned_by, -> (user) { user ? where(user:) : none }
  scope :removable_by, -> (user) { user&.admin? ? where(user_id: [nil, user.id]) : owned_by(user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :library, -> { where(kind: LIBRARY_KINDS) }
  scope :ordered, -> { order(:level_tag, :id) }

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

  def category
    body_data["category"].presence
  end

  def translations(locale)
    Array(body_data.dig("translations", locale.to_s))
  end
end
