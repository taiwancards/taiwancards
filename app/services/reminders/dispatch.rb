# frozen_string_literal: true

module Reminders
  class Dispatch
    include Rails.application.routes.url_helpers

    def self.welcome(user)
      return [] unless user.reminders? && user.verified? && !Setting.instance.reminders_paused?

      new.call([Planner::Plan.new(user:, trigger: Schedule::WELCOME, count: 0)])
    end

    def initialize(now: Time.current)
      @now = now
    end

    def call(plans = nil)
      return [] unless MailSettings.ready?

      (plans || Planner.new(now: @now).call).first(room).map do |plan|
        delivery = ReminderDelivery.create!(
          user: plan.user,
          trigger: plan.trigger,
          count: plan.count,
          path: target(plan),
          locale: plan.user.locale
        )
        ReminderDeliveryJob.perform_later(delivery.id)
        delivery
      end
    end

    private

    def room
      since = @now - 24.hours
      sent = NewsletterDelivery.sent_since(since).count + ReminderDelivery.where(created_at: since..).count
      [MailSettings.daily_limit - sent, 0].max
    end

    def target(plan)
      if Schedule.card_triggers.include?(plan.trigger)
        return study_path(mode: "daily", size: plan.count, locale: plan.user.locale)
      end

      desk_path(locale: plan.user.locale)
    end
  end
end
