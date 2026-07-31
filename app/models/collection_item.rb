# frozen_string_literal: true

class CollectionItem < ApplicationRecord
  self.primary_key = %i[collection_id lexeme_id]

  belongs_to :collection, counter_cache: :items_count
  belongs_to :lexeme

  scope :ordered, -> { order(:position) }
end
