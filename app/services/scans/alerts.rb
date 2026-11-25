# frozen_string_literal: true

module Scans
  module Alerts
    KINDS = %w[rejected credit ceiling expiring].freeze

    module_function

    def notify(kind, at: Time.current)
      ScanAlertJob.perform_later(KINDS.fetch(KINDS.index(kind)), at.iso8601)
      true
    rescue StandardError => error
      Rails.logger.error("scan alert #{kind} was not queued: #{error.class.name}")
      false
    end
  end
end
