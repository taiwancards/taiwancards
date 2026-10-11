# frozen_string_literal: true

module RemindersHelper
  def reminder_day_name(day) = t("date.abbr_day_names")[day % 7]

  def reminder_hour_label(hour) = format("%02d:00", hour)

  def reminder_schedule_text(days, hour)
    return t("admin.mail.schedule_none") if days.empty?

    "#{days.map { |day| reminder_day_name(day) }.join(", ")} · #{reminder_hour_label(hour)}"
  end

  def reminder_session_note(user)
    return t("reminders.session.on") unless user.reminder_fixed?
    return t("reminders.session.no_days") if user.reminder_days.empty?

    t("reminders.session.fixed", schedule: reminder_schedule_text(user.reminder_days, user.reminder_hour))
  end

  def mail_event_detail(event)
    return event.detail unless event.event == "scheduled"
    return t("admin.mail.schedule_auto") if event.detail == ReminderSchedule::AUTO

    days, hour, zone = event.detail.split("|", -1)
    [reminder_schedule_text(days.to_s.split(",").map(&:to_i), hour.to_i), zone].compact_blank.join(" · ")
  end
end
