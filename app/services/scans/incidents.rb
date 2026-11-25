# frozen_string_literal: true

module Scans
  module Incidents
    ALERTED = %w[credit ceiling].freeze
    KEPT = %w[ceiling].freeze

    module_function

    def pause(reason)
      pause = ScanPause.trip!(reason)
      Alerts.notify(reason, at: pause.created_at) if pause.previously_new_record? && ALERTED.include?(reason)
      pause
    end

    def report(failure, key)
      Credentials.rejected(key) if failure.rejected?
      pause(failure.pause) if failure.pause
    rescue StandardError => error
      Rails.logger.error("scan incident was not recorded: #{error.class.name}")
      nil
    end

    def reopen(now = Time.current)
      ScanPause.active.where.not(reason: KEPT).update_all(resumes_at: now - 1.second)
    end
  end
end
