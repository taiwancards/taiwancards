# frozen_string_literal: true

module ScanKeyGuard
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
    before_action { no_store }
    rate_limit(
      to: 12,
      within: 10.minutes,
      unless: -> { request.get? || request.head? },
      name: "scan-key",
      scope: "admin/scan-key",
      with: -> { redirect_to(admin_scans_path, alert: t("scan.admin.key.too_fast"), status: :see_other) }
    )
  end
end
