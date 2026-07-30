# frozen_string_literal: true

class Collection < ApplicationRecord
  belongs_to :user, optional: true
  has_many :collection_items, -> { order(:position) }, dependent: :destroy, inverse_of: :collection
  has_many :lexemes, through: :collection_items

  enum :kind, {manual: 0, lesson: 1, tocfl: 2, phrases: 3, everyday: 4}

  validates :name, presence: true, uniqueness: {scope: :user_id}

  scope :ordered, -> { order(:position, :name) }
  scope :desks_for, -> (user) { where(kind: :manual, user:) }
  scope :recent, -> { order(Arel.sql("last_used_at DESC NULLS LAST"), updated_at: :desc) }

  def add_lexeme(lexeme, position: nil)
    collection_items.find_or_create_by!(lexeme:) do |item|
      item.position = position || collection_items.maximum(:position).to_i + 1
    end
  end

  def study_facets
    Array(settings["facets"]) & LexemeMemory.facets.keys
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end
end
