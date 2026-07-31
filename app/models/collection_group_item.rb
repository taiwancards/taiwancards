# frozen_string_literal: true

class CollectionGroupItem < ApplicationRecord
  self.primary_key = %i[collection_group_id collection_id]

  belongs_to :collection_group
  belongs_to :collection

  scope :ordered, -> { order(:position) }
end
