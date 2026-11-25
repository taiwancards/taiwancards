# frozen_string_literal: true

class ScanAlertJob < ApplicationJob
  LIST = "alerts"

  def perform(kind, at)
    email = User.owner_email
    return if email.nil? || !MailSettings.ready?

    owner = User.find_by(email:)
    message = ScanAlertMailer.alert(kind:, at: Time.zone.parse(at), email:, locale: owner&.locale)
    message.deliver_now
    journal(owner, email, kind, "sent", letter: message.subject)
  rescue StandardError => error
    journal(owner, email, kind, "failed", detail: "#{error.class}: #{error.message}".first(250)) if email
  end

  private

  def journal(owner, email, kind, event, letter: kind, detail: "")
    MailEvent.log(owner, email:, list: LIST, event:, letter:, detail:, summary: "scan #{kind}")
  end
end
