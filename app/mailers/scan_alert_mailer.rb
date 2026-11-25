# frozen_string_literal: true

class ScanAlertMailer < ActionMailer::Base
  layout false

  def alert(kind:, at:, email:, locale:)
    @kind = Scans::Alerts::KINDS.fetch(Scans::Alerts::KINDS.index(kind))
    I18n.with_locale(locale.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale) do
      @at = I18n.l(at.in_time_zone(Time.zone_default), format: :long)
      @admin_url = admin_scans_url(locale: I18n.locale)
      @scope = "scan.alerts.#{@kind}"
      @subject = t("#{@scope}.subject")

      mail(
        to: email,
        from: email_address_with_name(MailSettings.from_address, t("newsletters.mail.from_name")),
        subject: @subject
      )
    end
  end
end
