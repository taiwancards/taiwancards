# frozen_string_literal: true

class LexemeReview < ApplicationRecord
  belongs_to :lexeme_memory
  belongs_to :lexeme
  belongs_to :user, optional: true

  enum :facet, {recognition: 0, production: 1, reading: 2, tone: 3, writing: 4, listening: 5}, prefix: :facet

  scope :owned_by, -> (user) { where(user:) }

  before_create :stamp_day

  private

  def stamp_day
    return if reviewed_on

    self.reviewed_on = day_in(user&.zone)
    bridge_move if user&.previous_zone
  end

  def day_in(zone) = reviewed_at.in_time_zone(zone || Time.zone_default).to_date

  def bridge_move
    last = LexemeReview.owned_by(user).order(reviewed_at: :desc).pick(:reviewed_on)
    self.reviewed_on = last + 1 if last && reviewed_on > last + 1 && day_in(user.previous_zone) <= last + 1
    user.update_column(:previous_time_zone, nil)
  end
end
