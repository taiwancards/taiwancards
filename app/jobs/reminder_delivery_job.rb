# frozen_string_literal: true

class ReminderDeliveryJob < ApplicationJob
  def perform(delivery_id)
    delivery = ReminderDelivery.includes(:user).find_by(id: delivery_id)
    return if delivery.nil? || delivery.sent_at

    ReminderMailer.nudge(delivery).deliver_now
    delivery.update_columns(sent_at: Time.current)
    log(delivery, "sent")
  rescue StandardError => error
    message = "#{error.class}: #{error.message}".first(250)
    delivery&.update_columns(error: message)
    log(delivery, "failed", detail: message) if delivery
  end

  private

  def log(delivery, event, detail: "")
    MailEvent.log(
      delivery.user,
      list: "reminders",
      event:,
      letter: delivery.trigger,
      detail:,
      count: delivery.count,
      summary: Reminders::Letter.new(delivery).summary
    )
  end
end
