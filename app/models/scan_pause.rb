# frozen_string_literal: true

class ScanPause < ApplicationRecord
  LOCK = 0x5ca8
  LENGTHS = {
    "credit" => -> { 6.hours.from_now },
    "rate_limited" => -> { 5.minutes.from_now },
    "unavailable" => -> { 2.minutes.from_now },
    "ceiling" => -> { Time.current.in_time_zone(Time.zone_default).end_of_day }
  }.freeze

  validates :reason, inclusion: {in: LENGTHS.keys}

  scope :active, -> { where(resumes_at: Time.current..) }
  scope :recent, -> { order(created_at: :desc) }

  def self.current = active.order(resumes_at: :desc).first

  def self.trip!(reason)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{LOCK})")
      active.find_by(reason:) || create!(reason:, resumes_at: LENGTHS.fetch(reason).call)
    end
  end
end
