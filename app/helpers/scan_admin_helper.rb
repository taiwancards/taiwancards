# frozen_string_literal: true

module ScanAdminHelper
  def scan_state_label(health, pause)
    return t("scan.admin.no_key") if health.status == "missing"
    return t("scan.admin.key.status.rejected") if health.status == "rejected"
    return t("scan.admin.paused", reason: pause.reason, until: l(pause.resumes_at, format: :short)) if pause

    t("scan.admin.open")
  end

  def scan_key_expiry(days)
    return t("scan.admin.key.never") if days.nil?
    return t("scan.admin.key.expired", count: -days) if days.negative?
    return t("scan.admin.key.expires_today") if days.zero?

    t("scan.admin.key.expires_in", count: days)
  end

  def scan_model_options
    Scans::Pricing::PER_MILLION.map do |model, (input, output)|
      ["#{model} · $#{input.to_s.delete_suffix(".0")} / $#{output.to_s.delete_suffix(".0")}", model]
    end
  end

  def scan_moment(time) = time ? l(time.in_time_zone(Time.zone_default), format: :short) : "—"

  def scan_health
    return @scan_health if defined?(@scan_health)

    @scan_health = Scans::Health.new
  end
end
