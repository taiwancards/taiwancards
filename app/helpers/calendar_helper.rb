# frozen_string_literal: true

module CalendarHelper
  def lunar_label(lunar)
    return nil if lunar.nil?

    month = Huayu::LunarCalendar.month_label(lunar[:month], leap: lunar[:leap])
    "#{month}#{Huayu::LunarCalendar.day_label(lunar[:day])}"
  end

  def holiday_badge_class(public_holiday)
    if public_holiday
      "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400"
    else
      "bg-muted text-muted-foreground"
    end
  end
end
