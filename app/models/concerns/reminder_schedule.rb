# frozen_string_literal: true

module ReminderSchedule
  extend ActiveSupport::Concern

  MODES = %w[auto fixed].freeze
  WEEKDAYS = (1..7).to_a.freeze
  HOURS = (0..23).to_a.freeze
  AUTO = "auto"

  class_methods do
    def reminder_schedule_key(prefs)
      return AUTO unless prefs["reminder_mode"] == "fixed"

      days = (Array(prefs["reminder_days"]).map(&:to_i) & WEEKDAYS).sort
      "#{days.join(",")}|#{prefs["reminder_hour"]}"
    end
  end

  def reminder_mode = prefs["reminder_mode"].presence_in(MODES) || AUTO

  def reminder_fixed? = reminder_mode == "fixed"

  def reminder_days = (Array(prefs["reminder_days"]).map(&:to_i) & WEEKDAYS).sort

  def reminder_hour = prefs["reminder_hour"]&.to_i&.clamp(HOURS.first, HOURS.last) || Reminders::Schedule.default_hour

  def reminder_time?(local) = reminder_fixed? &&
    reminder_days.include?(local.to_date.cwday) &&
    local.hour == reminder_hour

  def reminder_schedule = {mode: reminder_mode, days: reminder_days, hour: reminder_hour}

  def reminder_schedule=(values)
    values = values.to_h.stringify_keys
    hour = values["hour"].presence&.to_i
    write_prefs(
      "reminder_mode" => values["mode"].presence_in(MODES) || AUTO,
      "reminder_days" => (Array(values["days"]).compact_blank.map(&:to_i) & WEEKDAYS).sort,
      "reminder_hour" => hour&.clamp(HOURS.first, HOURS.last) || reminder_hour
    )
  end

  private

  def reminder_schedule_changed?
    return false unless saved_change_to_prefs?

    before, after = saved_change_to_prefs
    self.class.reminder_schedule_key(before || {}) != self.class.reminder_schedule_key(after || {})
  end

  def log_reminder_schedule
    return unless reminder_schedule_changed?

    key = self.class.reminder_schedule_key(prefs)
    detail = key == AUTO ? key : "#{key}|#{time_zone || Time.zone_default.tzinfo.name}"
    MailEvent.log(self, list: "reminders", event: "scheduled", source: mailing_source || "profile", detail:)
  end
end
