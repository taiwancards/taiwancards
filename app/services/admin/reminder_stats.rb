# frozen_string_literal: true

module Admin
  class ReminderStats
    RECENT = 60
    RETURN_DAYS = 2

    Row = Data.define(:trigger, :sent, :failed, :clicked, :returned, :click_hours)

    def triggers
      sql = ActiveRecord::Base.sanitize_sql_array(
        [
          <<~SQL
            SELECT r.trigger,
                   COUNT(r.sent_at) AS sent,
                   COUNT(r.error) AS failed,
                   COUNT(r.clicked_at) AS clicked,
                   COUNT(*) FILTER (WHERE EXISTS (
                     SELECT 1 FROM user_days d
                     WHERE d.user_id = r.user_id
                       AND d.day BETWEEN DATE(r.sent_at AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(u.time_zone, :zone))
                                     AND DATE(r.sent_at AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(u.time_zone, :zone)) + :days
                   )) AS returned,
                   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM r.clicked_at - r.sent_at) / 3600) AS click_hours
            FROM reminder_deliveries r JOIN users u ON u.id = r.user_id
            GROUP BY r.trigger
            ORDER BY r.trigger
          SQL
            .squish,
          {days: RETURN_DAYS, zone: Time.zone_default.tzinfo.name}
        ]
      )
      ActiveRecord::Base.connection.select_all(sql).map { |row| Row.new(**row.symbolize_keys) }
    end

    def recent = ReminderDelivery.includes(:user).recent.limit(RECENT)

    def returned_ids(deliveries)
      pairs = deliveries.select(&:sent_at).map { |delivery| [delivery.user_id, sent_on(delivery)] }
      return Set.new if pairs.empty?

      days = UserDay
        .where(user_id: pairs.map(&:first).uniq, day: pairs.map(&:last).min..)
        .pluck(:user_id, :day)
        .group_by(&:first)
      deliveries
        .select do |delivery|
          delivery.sent_at &&
            Array(days[delivery.user_id]).any? { |_id, day|
              (sent_on(delivery)..(sent_on(delivery) + RETURN_DAYS)).cover?(day)
            }
        end
        .to_set(&:id)
    end

    def opted_out = User.where.not(reminders_off_at: nil).count

    private

    def sent_on(delivery) = delivery.sent_at.in_time_zone(delivery.user.zone || Time.zone_default).to_date
  end
end
