# frozen_string_literal: true

module Reminders
  module Schedule
    WELCOME = "welcome"
    SCHEDULED = "scheduled"

    module_function

    def settings = @settings ||= Rails.application.config_for(:reminders)

    def default_hour = settings.fetch(:default_hour)

    def quiet_hours = settings.fetch(:quiet_hours)

    def give_up_after = settings.fetch(:give_up_after)

    def history_days = settings.fetch(:history_days)

    def seconds_per_card = settings.fetch(:seconds_per_card)

    def dose = settings.fetch(:dose)

    def signup_days = Array(settings.dig(:triggers, :first_cards, :days_after_signup))

    def away_days = Array(settings.dig(:triggers, :due_cards, :days_away))

    def lapse_triggers = Array(settings.dig(:triggers, :due_cards, :names)).first(away_days.size)

    def card_triggers = [*lapse_triggers, SCHEDULED]

    def minutes(count) = [(count * seconds_per_card / 60.0).ceil, 1].max
  end
end
