# frozen_string_literal: true

class UserDay < ApplicationRecord
  self.primary_key = %i[user_id day]

  belongs_to :user

  def self.record(user, at: Time.current)
    insert_all([{user_id: user.id, day: at.in_time_zone(user.zone || Time.zone_default).to_date}])
  end
end
