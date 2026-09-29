# frozen_string_literal: true

class NewsletterDelivery < ApplicationRecord
  belongs_to :newsletter
  belongs_to :user

  scope :pending, -> { where(sent_at: nil) }
  scope :sent, -> { where.not(sent_at: nil) }
  scope :clicked, -> { where.not(clicked_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }

  def self.sent_since(time) = sent.where(sent_at: time..)

  def self.claim(id) = pending.where(id:).update_all(sent_at: Time.current, error: nil) == 1

  def record_click!
    self
      .class
      .where(id:)
      .update_all(["clicks_count = clicks_count + 1, clicked_at = COALESCE(clicked_at, ?)", Time.current])
  end
end
