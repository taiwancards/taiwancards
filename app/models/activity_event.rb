# frozen_string_literal: true

class ActivityEvent < ApplicationRecord
  SKIPPED_CONTROLLERS = %w[rails/health sessions admin/activity admin/impersonations].freeze
  RETENTION = 30.days
  WINDOW = 10.minutes
  TRACKED_USERS = 4096
  SWEEP_INTERVAL = 1.day
  SWEEP_BATCH = 5_000

  belongs_to :user, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :since, -> (time) { where(created_at: time..) }
  scope :expired, -> (before = RETENTION.ago) { where(created_at: ...before) }

  class << self
    def record(user:, controller:, action:, verb:, path:)
      return if user.nil? || SKIPPED_CONTROLLERS.include?(controller)
      return unless fresh?(user, controller, action)

      event = create!(user:, controller:, action:, verb:, path: path.to_s.first(255), created_at: Time.current)
      sweep
      event
    rescue => e
      Rails.logger.warn("activity tracking failed: #{e.class}: #{e.message}")
    end

    def prune(before: RETENTION.ago, batch: SWEEP_BATCH)
      where(id: expired(before).limit(batch).select(:id)).delete_all
    end

    def prune_all(before: RETENTION.ago)
      total = 0

      loop do
        removed = prune(before:)
        break total if removed.zero?

        total += removed
      end
    end

    def forget_seen
      seen.clear
      sweeps.clear
    end

    private

    def sweep
      return unless sweeps.once("prune")

      removed = prune
      Rails.logger.info("activity: pruned #{removed} event(s)") if removed.positive?
    end

    def fresh?(user, controller, action)
      seen.once("#{user.id}/#{controller}/#{action}")
    end

    def seen
      @seen ||= ProcessCache.new(ttl: WINDOW, limit: TRACKED_USERS)
    end

    def sweeps
      @sweeps ||= ProcessCache.new(ttl: SWEEP_INTERVAL, limit: 1)
    end
  end

  def section
    controller.split("/").last.humanize
  end
end
