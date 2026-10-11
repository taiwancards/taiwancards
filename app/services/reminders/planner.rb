# frozen_string_literal: true

module Reminders
  class Planner
    Plan = Data.define(:user, :trigger, :count)

    def initialize(now: Time.current)
      @now = now
    end

    def call
      candidates.filter_map { |user| plan_for(user) }.sort_by { |plan| plan.trigger == Schedule::SCHEDULED ? 0 : 1 }
    end

    private

    def candidates
      users = User.where(reminders_off_at: nil).where.not(email_verified_at: nil).to_a
      fixed, auto = users.partition(&:reminder_fixed?)
      auto = [] if Setting.instance.reminders_paused?
      hours = usual_hours(auto.map(&:id))
      fixed.select { |user| user.reminder_time?(local(user)) } +
        auto.select { |user| local(user).hour == hours.fetch(user.id, Schedule.default_hour) }
    end

    def plan_for(user)
      return scheduled(user) if user.reminder_fixed?

      days = UserDay.where(user:).pick(Arel.sql("MIN(day)"), Arel.sql("MAX(day)"))
      first_day, last_day = days
      return nil if first_day.nil?

      deliveries = ReminderDelivery
        .where(user:, error: nil)
        .where
        .not(trigger: Schedule::WELCOME)
        .recent
        .limit(Schedule.give_up_after + Schedule.away_days.size)
        .to_a
      return nil if quiet?(deliveries) || given_up?(user, deliveries, last_day)

      today = local(user).to_date
      if LexemeReview.where(user:).none?
        first_cards(user, deliveries, (today - first_day).to_i)
      else
        due_cards(user, deliveries, last_day, (today - last_day).to_i)
      end
    end

    def scheduled(user)
      there = local(user)
      return nil if LexemeReview.where(user:, reviewed_on: there.to_date).exists?
      return nil if ReminderDelivery.where(user:, trigger: Schedule::SCHEDULED, created_at: there.all_day).exists?

      summary = Study::TodayDesk.new(user, now: @now).summary
      waiting = summary[:due] + summary[:new]
      waiting.positive? ? Plan.new(user:, trigger: Schedule::SCHEDULED, count: Dose.new(user, now: @now).call(waiting)) : nil
    end

    def first_cards(user, deliveries, age)
      return nil unless Schedule.signup_days.include?(age)
      return nil if deliveries.any? { |delivery| delivery.trigger == "first_cards" }

      Plan.new(user:, trigger: "first_cards", count: 0)
    end

    def due_cards(user, deliveries, last_day, away)
      step = Schedule.away_days.index(away)
      return nil if step.nil?

      triggers = Schedule.lapse_triggers
      sent = deliveries.count { |delivery| triggers.include?(delivery.trigger) && day_of(user, delivery) > last_day }
      return nil if sent > step

      due = Study::TodayDesk.new(user, now: @now).summary[:due]
      due.positive? ? Plan.new(user:, trigger: triggers[step], count: Dose.new(user, now: @now).call(due)) : nil
    end

    def quiet?(deliveries)
      deliveries.first && deliveries.first.created_at > @now - Schedule.quiet_hours.hours
    end

    def given_up?(user, deliveries, last_day)
      ignored = deliveries.take_while { |delivery| delivery.ignored? && day_of(user, delivery) >= last_day }
      ignored.size >= Schedule.give_up_after
    end

    def usual_hours(ids)
      return {} if ids.empty?

      zone = ActiveRecord::Base.connection.quote(Time.zone_default.tzinfo.name)
      hour = "EXTRACT(HOUR FROM lexeme_reviews.reviewed_at AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(users.time_zone, #{zone}))"
      LexemeReview
        .joins(:user)
        .where(user_id: ids, reviewed_at: (@now - Schedule.history_days.days)..)
        .group(:user_id)
        .pluck(:user_id, Arel.sql("PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY #{hour})"))
        .to_h { |id, value| [id, value.to_i] }
    end

    def local(user) = @now.in_time_zone(user.zone || Time.zone_default)

    def day_of(user, delivery) = delivery.created_at.in_time_zone(user.zone || Time.zone_default).to_date
  end
end
