# frozen_string_literal: true

class NewsletterDispatchJob < ApplicationJob
  class_attribute :pause, default: 0.6

  def perform(newsletter_id)
    newsletter = Newsletter.find_by(id: newsletter_id)
    return if newsletter.nil?

    pending = newsletter.deliveries.pending
    pending.where.not(user_id: Newsletter.recipients.select(:id)).delete_all
    pending.order(:id).limit(Newsletters::Dispatch.budget).pluck(:id).each do |id|
      next unless NewsletterDelivery.claim(id)

      deliver(NewsletterDelivery.find(id))
      sleep(pause) if pause.positive?
    end
  end

  private

  def deliver(delivery)
    NewsletterMailer.issue(delivery).deliver_now
  rescue StandardError => error
    delivery.update_columns(sent_at: nil, error: "#{error.class}: #{error.message}".first(250))
  end
end
