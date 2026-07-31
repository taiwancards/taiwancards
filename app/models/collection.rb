# frozen_string_literal: true

class Collection < ApplicationRecord
  MAX_ITEMS = 1_000
  SOFT_LIMIT = 500

  belongs_to :user, optional: true
  has_many :collection_items, -> { order(:position) }, dependent: :delete_all, inverse_of: :collection
  has_many :lexemes, through: :collection_items
  has_many :collection_group_items, dependent: :delete_all, inverse_of: :collection
  has_many :groups, through: :collection_group_items, source: :collection_group

  enum :kind, {manual: 0, lesson: 1, tocfl: 2, phrases: 3, everyday: 4}

  validates :name, presence: true, length: {maximum: 200}, uniqueness: {scope: :user_id}

  scope :ordered, -> { order(:position, :name) }
  scope :desks_for, -> (user) { where(kind: :manual, user:) }
  scope :recent, -> { order(Arel.sql("last_used_at DESC NULLS LAST"), updated_at: :desc) }
  scope :arranged, -> { order(:position, :id) }

  def add_lexeme(lexeme, position: nil)
    add_lexemes([lexeme.id], start: position)
  end

  def add_lexemes(lexeme_ids, start: nil)
    ids = normalize(lexeme_ids)
    room = room_left
    ids = ids.first(room) if room
    return 0 if ids.empty?

    base = start || (collection_items.maximum(:position).to_i + 1)
    inserted = CollectionItem
      .insert_all(
        ids.each_with_index.map { |lexeme_id, index| {collection_id: id, lexeme_id:, position: base + index} },
        unique_by: %i[collection_id lexeme_id],
        returning: %w[lexeme_id]
      )
      .length
    bump_items_count(inserted)
    inserted
  end

  def remove_lexemes(lexeme_ids)
    ids = normalize(lexeme_ids)
    return 0 if ids.empty?

    removed = collection_items.where(lexeme_id: ids).delete_all
    bump_items_count(-removed)
    removed
  end

  def replace_lexemes(lexeme_ids)
    ids = normalize(lexeme_ids)
    ceiling = capacity
    ids = ids.first(ceiling) if ceiling
    transaction do
      collection_items.delete_all
      next if ids.empty?

      CollectionItem.insert_all(
        ids.each_with_index.map { |lexeme_id, index| {collection_id: id, lexeme_id:, position: index} }
      )
    end

    update_column(:items_count, ids.size)
    ids.size
  end

  def duplicate_for(owner, name: nil)
    copy = Collection.create!(
      user: owner,
      kind: :manual,
      name: name.presence || self.name(),
      settings: settings,
      last_used_at: Time.current
    )
    self.class.connection.exec_update(
      self.class.sanitize_sql_array(
        [
          "INSERT INTO collection_items (collection_id, lexeme_id, position) " \
            "SELECT ?, lexeme_id, position FROM collection_items " \
            "WHERE collection_id = ? ORDER BY position LIMIT ? ON CONFLICT DO NOTHING",
          copy.id,
          id,
          MAX_ITEMS
        ]
      )
    )
    copy.sync_items_count!
    copy
  end

  def ordered_lexeme_ids(limit: nil, offset: nil)
    collection_items.order(:position).limit(limit).offset(offset).pluck(:lexeme_id)
  end

  def capacity
    MAX_ITEMS if manual? && user_id
  end

  def study_facets
    Array(settings["facets"]) & LexemeMemory.facets.keys
  end

  def touch_used!
    update_column(:last_used_at, Time.current)
  end

  def sync_items_count!
    update_column(:items_count, collection_items.count)
  end

  def room_left
    ceiling = capacity
    ceiling ? [ceiling - items_count, 0].max : nil
  end

  private

  def bump_items_count(delta)
    return if delta.zero?

    self.class.update_counters(id, items_count: delta)
    self.items_count = (items_count + delta).clamp(0, nil)
    clear_attribute_changes([:items_count])
  end

  def normalize(lexeme_ids)
    Array(lexeme_ids).map(&:to_i).reject(&:zero?).uniq
  end
end
