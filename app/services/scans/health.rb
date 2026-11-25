# frozen_string_literal: true

module Scans
  class Health
    EXPIRY_WARNING_DAYS = 2

    attr_reader :credential

    def initialize(credential: ScanCredential.current, today: Time.current.in_time_zone(Time.zone_default).to_date)
      @credential = credential
      @today = today
    end

    def issues
      @issues ||= [
        ("missing" if status == "missing"),
        ("rejected" if status == "rejected"),
        ("expiring" if expiring?),
        ("credit" if ScanPause.active.exists?(reason: "credit"))
      ].compact
    end

    def healthy? = issues.empty?

    def headline = issues.first

    def status = @status ||= credential.status

    def days_left = credential.stored_key && credential.days_left(@today)

    def expiring?
      days = days_left
      !days.nil? && days <= EXPIRY_WARNING_DAYS
    end
  end
end
