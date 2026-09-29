# frozen_string_literal: true

module Newsletters
  class Dispatch
    UNIQUE = :index_newsletter_deliveries_on_newsletter_and_user

    def self.budget = [MailSettings.daily_limit - NewsletterDelivery.sent_since(24.hours.ago).count, 0].max

    def initialize(newsletter)
      @newsletter = newsletter
    end

    def call
      enroll unless @newsletter.sent?
      NewsletterDispatchJob.perform_later(@newsletter.id)
    end

    private

    def enroll
      now = Time.current
      rows = Newsletter.recipients.pluck(:id, :locale).map { |id, locale|
        {
          newsletter_id: @newsletter.id,
          user_id: id,
          locale: locale.presence_in(Newsletter::LOCALES) || "en",
          created_at: now,
          updated_at: now
        }
      }
      NewsletterDelivery.upsert_all(rows, unique_by: UNIQUE, update_only: %i[locale]) if rows.any?
      @newsletter.update!(sent_at: now)
    end
  end
end
