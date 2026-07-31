# frozen_string_literal: true

class UserPresence < ActiveRecord::Migration[8.1]
  def change
    add_column("users", "last_seen_at", :datetime)
    add_column("users", "visits_count", :integer, default: 0, null: false)
  end
end
