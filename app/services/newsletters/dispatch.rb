# frozen_string_literal: true

module Newsletters
  class Dispatch
    UNIQUE = :index_newsletter_deliveries_on_newsletter_and_user

    def self.budget = MailQuota.left_for_newsletters

    def self.resume
      return 0 unless MailSettings.ready? && budget.positive?

      newsletter = Newsletter
        .where
        .not(sent_at: nil)
        .where(id: NewsletterDelivery.pending.where(error: nil).select(:newsletter_id))
        .order(:sent_at)
        .first
      return 0 if newsletter.nil?

      NewsletterDispatchJob.perform_later(newsletter.id, retry_failed: false)
      1
    end

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
      rows = @newsletter.audience_recipients.pluck(:id, :locale).map { |id, locale|
        {
          newsletter_id: @newsletter.id,
          user_id: id,
          locale: locale.presence_in(Newsletter::LOCALES) || Locales::DEFAULT,
          created_at: now,
          updated_at: now
        }
      }
      NewsletterDelivery.upsert_all(rows, unique_by: UNIQUE, update_only: %i[locale]) if rows.any?
      @newsletter.update!(sent_at: now)
    end
  end
end
