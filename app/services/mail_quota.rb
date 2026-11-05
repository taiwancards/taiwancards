# frozen_string_literal: true

module MailQuota
  module_function

  def left(now = Time.current)
    since = now - 24.hours
    sent = NewsletterDelivery.sent_since(since).count + ReminderDelivery.where(created_at: since..).count
    [MailSettings.daily_limit - sent, 0].max
  end

  def left_for_newsletters(now = Time.current)
    share = MailSettings.daily_limit - MailSettings.reminder_reserve
    [share - NewsletterDelivery.sent_since(now - 24.hours).count, left(now)].min.clamp(0..)
  end
end
