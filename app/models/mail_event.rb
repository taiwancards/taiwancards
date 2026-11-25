# frozen_string_literal: true

class MailEvent < ApplicationRecord
  LISTS = %w[reminders newsletter alerts].freeze
  EVENTS = %w[sent failed clicked unsubscribed subscribed scheduled paused resumed].freeze
  SUMMARY_LIMIT = 600
  ERROR_KIND = "^[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*"
  SCHEDULE_WITHOUT_ZONE = "^([^|]*[|][^|]*)[|].*$"

  belongs_to :user, optional: true

  validates :email, presence: true, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def self.anonymize!
    update_all(
      <<~SQL
        user_id = NULL,
        email = NULL,
        detail = CASE event
          WHEN 'failed' THEN COALESCE(substring(detail FROM '#{ERROR_KIND}'), '')
          WHEN 'scheduled' THEN regexp_replace(detail, '#{SCHEDULE_WITHOUT_ZONE}', '\\1')
          ELSE detail
        END
      SQL
        .squish
    )
  end

  def self.source_for(params) = params["List-Unsubscribe"] == "One-Click" ? "one_click" : "email_link"

  def self.log(
    user,
    list:,
    event:,
    letter: "",
    source: "",
    detail: "",
    count: nil,
    summary: "",
    at: Time.current,
    email: user&.email
  )
    create!(
      user:,
      email:,
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
