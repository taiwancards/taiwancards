# frozen_string_literal: true

module Scans
  class Panel
    attr_reader :remaining, :pause

    def self.remaining(user)
      count = Scan.remaining(user)
      {remaining: count, remaining_label: label(count)}
    end

    def self.label(count) = I18n.t("scan.remaining", count:, daily: Scan::DAILY)

    def initialize(user)
      @remaining = Scan.remaining(user)
      @pause = ScanPause.current
      @usable = Settings.usable?
    end

    def remaining_label = self.class.label(remaining)

    def open? = @usable && pause.nil?

    def closed_reason
      return "unavailable" unless @usable

      "paused" if pause
    end
  end
end
