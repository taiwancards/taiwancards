# frozen_string_literal: true

module Reminders
  class Letter
    def initialize(delivery)
      @delivery = delivery
    end

    def key = "reminders.mail.#{@delivery.trigger}"

    def vars = {count: @delivery.count, minutes: Schedule.minutes(@delivery.count)}

    def welcome? = @delivery.trigger == Schedule::WELCOME

    def subject = I18n.t("#{key}.subject", **vars)

    def summary
      I18n.with_locale(@delivery.locale) do
        main = welcome? ? I18n.t("#{key}.features").map { |feature| feature[:title] }.join(", ") : body
        [subject.sub(/[.!?…]\z/, ""), main].join(". ")
      end
    end

    private

    def body = Array.wrap(I18n.t("#{key}.body", **vars)).join(" ")
  end
end
