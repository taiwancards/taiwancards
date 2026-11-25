# frozen_string_literal: true

class ScanWatchJob < ApplicationJob
  def perform
    Scan.purge_expired
    Scans::Credentials.watch
  rescue StandardError => error
    Rails.logger.error("scan key watch failed: #{error.class.name}")
  end
end
