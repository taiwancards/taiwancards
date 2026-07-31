# frozen_string_literal: true

class CollectionGroup < ApplicationRecord
  MAX_PER_USER = 100

  belongs_to :user
  has_many :collection_group_items, dependent: :delete_all, inverse_of: :collection_group
  has_many :collections, through: :collection_group_items

  validates :name, presence: true, length: {maximum: 120}, uniqueness: {scope: :user_id}

  scope :ordered, -> { order(:position, :id) }
  scope :owned_by, -> (user) { where(user:) }

  def add_collections(collection_ids)
    ids = Array(collection_ids).map(&:to_i).uniq
    return 0 if ids.empty?

    base = collection_group_items.maximum(:position).to_i + 1
    rows = ids.each_with_index.map do |collection_id, index|
      {collection_group_id: id, collection_id:, position: base + index}
    end

    CollectionGroupItem.insert_all(rows, unique_by: %i[collection_group_id collection_id])
    sync_collections_count!
  end

  def remove_collections(collection_ids)
    ids = Array(collection_ids).map(&:to_i).uniq
    return 0 if ids.empty?

    collection_group_items.where(collection_id: ids).delete_all
    sync_collections_count!
  end

  def reorder_collections(collection_ids)
    Collections::Reorder.call(collection_group_items, collection_ids, key: :collection_id)
  end

  def sync_collections_count!
    update_column(:collections_count, collection_group_items.count)
  end
end
