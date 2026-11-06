# frozen_string_literal: true

class AllowGuestPlacementTests < ActiveRecord::Migration[8.1]
  def change
    change_column_null(:placement_tests, :user_id, true)
  end
end
