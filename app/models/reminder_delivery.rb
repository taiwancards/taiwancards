# frozen_string_literal: true

class ReminderDelivery < ApplicationRecord
  belongs_to :user

  scope :recent, -> { order(created_at: :desc) }

  def record_click!(at: Time.current) = update_columns(clicked_at: clicked_at || at)

  def ignored? = clicked_at.nil?
end
