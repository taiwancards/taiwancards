# frozen_string_literal: true

class LearnerDays < ActiveRecord::Migration[8.1]
  def up
    add_column("users", "time_zone", :string)
    add_column("users", "previous_time_zone", :string)
    add_column("lexeme_reviews", "reviewed_on", :date)
    execute("UPDATE lexeme_reviews SET reviewed_on = DATE(reviewed_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Taipei')")
    change_column_null("lexeme_reviews", "reviewed_on", false)
  end

  def down
    remove_column("lexeme_reviews", "reviewed_on")
    remove_column("users", "previous_time_zone")
    remove_column("users", "time_zone")
  end
end
