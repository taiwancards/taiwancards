# frozen_string_literal: true

module ProgressHelper
  ACTIVITY_SHADES = %w[bg-muted bg-emerald-500/30 bg-emerald-500/55 bg-emerald-500/80 bg-emerald-500].freeze
  REST_MARK = "inset-ring-2 inset-ring-emerald-600/70"
  STREAK_STATUSES = {done: "stats.streak_today", pending: "stats.streak_pending", resting: "stats.streak_resting"}.freeze

  def activity_shade(count, peak)
    return ACTIVITY_SHADES.first if count.zero?

    ACTIVITY_SHADES[(Math.sqrt(count.fdiv(peak)) * 4).ceil.clamp(1, 4)]
  end

  def activity_cell(date, count, peak, streak)
    day = l(date, format: :short)
    shade = activity_shade(count, peak)
    return {class: shade, title: "#{day}: #{count}"} unless streak.rest_on?(date)

    {class: "#{shade} #{REST_MARK}", title: t("stats.activity_rest", date: day)}
  end

  def streak_status(streak)
    return t("stats.streak_none") unless streak.since

    t(STREAK_STATUSES.fetch(streak.state), date: l(streak.since, format: :short))
  end

  def streak_rest_note(streak)
    ahead = streak.ahead
    case streak.state
    when :resting
      streak.allowance.zero? ? t("stats.streak_rest_used") : t("stats.streak_rest_left", count: streak.allowance)
    when :done, :pending
      return t("stats.streak_rest_earn", count: ahead.days, days: ahead.rest) if streak.allowance.zero?

      [
        t("stats.streak_rest_allowed", count: streak.allowance),
        ahead && t("stats.streak_rest_ahead", count: ahead.days, days: ahead.rest)
      ].compact.join(" ")
    end
  end

  def streak_rests_note(streak)
    return if streak.rests.empty?

    t("stats.streak_rests", count: streak.rests.length, date: l(streak.rests.last, format: :short))
  end
end
