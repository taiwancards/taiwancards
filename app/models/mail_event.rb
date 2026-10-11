# frozen_string_literal: true

class MailEvent < ApplicationRecord
  LISTS = %w[reminders newsletter].freeze
  EVENTS = %w[sent failed clicked unsubscribed subscribed scheduled paused resumed].freeze
  SUMMARY_LIMIT = 600

  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def self.source_for(params) = params["List-Unsubscribe"] == "One-Click" ? "one_click" : "email_link"

  def self.log(user, list:, event:, letter: "", source: "", detail: "", count: nil, summary: "", at: Time.current)
    create!(
      user:,
      email: user.email,
      list:,
      event:,
      letter: letter.to_s.first(255),
      source:,
      detail: detail.to_s.first(255),
      count:,
      summary: summary.to_s.squish.truncate(SUMMARY_LIMIT),
      created_at: at
    )
  rescue => e
    Rails.logger.warn("mail event failed: #{e.class}: #{e.message}")
    nil
  end
end
