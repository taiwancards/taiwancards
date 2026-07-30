# frozen_string_literal: true

class CollectionItem < ApplicationRecord
  belongs_to :collection, counter_cache: :items_count
  belongs_to :lexeme

  validates :lexeme_id, uniqueness: {scope: :collection_id}
end
