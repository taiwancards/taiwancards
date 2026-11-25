# frozen_string_literal: true

class Scan < ApplicationRecord
  DAILY = 10
  ATTEMPTS = DAILY * 2
  STALE_AFTER = 3.minutes
  KEPT_FOR = 24.hours
  IN_FLIGHT = %w[queued running].freeze
  REFUNDED = %w[interrupted timeout unavailable key rate_limited busy].freeze
  FAILURES = (REFUNDED + %w[refused too_much]).freeze

  belongs_to :user

  enum :state, {queued: 0, running: 1, done: 2, failed: 3}

  validates :failure, inclusion: {in: FAILURES}, allow_nil: true

  scope :in_flight, -> { where(state: IN_FLIGHT) }
  scope :stale, -> { in_flight.where(created_at: ...STALE_AFTER.ago) }
  scope :counted, -> { where(counted: true) }
  scope :expired, -> { where(created_at: ...KEPT_FOR.ago).where("text IS NOT NULL OR client_digest IS NOT NULL") }

  def self.learner_day(user, at: Time.current) = at.in_time_zone(user.zone || Time.zone_default).to_date

  def self.used(user, day: learner_day(user)) = where(user:, day:).counted.count

  def self.remaining(user, day: learner_day(user)) = [DAILY - used(user, day:), 0].max

  def self.reap_stale
    stale.find_each { |scan| scan.fail!("interrupted") }
  end

  def self.purge_expired
    expired.update_all(text: nil, changed_chars: [], client_digest: nil, updated_at: Time.current)
  end

  def claim!
    claimed = Scan.where(id:, state: :queued).update_all(state: Scan.states[:running], started_at: Time.current)
    reload
    claimed == 1
  end

  def finish!(text:, legibility:, changed:, usage:)
    settle(:running, state: :done, text:, legibility:, changed_chars: changed, **usage)
  end

  def fail!(failure, usage: {})
    settle(IN_FLIGHT, state: :failed, failure:, counted: !REFUNDED.include?(failure), **usage)
  end

  def pending? = IN_FLIGHT.include?(state)

  def overdue? = pending? && created_at < STALE_AFTER.ago

  private

  def settle(from, **changes)
    columns = changes.merge(finished_at: Time.current, updated_at: Time.current)
    columns[:state] = Scan.states.fetch(columns[:state].to_s)
    settled = Scan.where(id:, state: Array(from)).update_all(columns)
    reload
    settled == 1
  end
end
