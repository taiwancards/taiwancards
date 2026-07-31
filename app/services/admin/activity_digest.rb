# frozen_string_literal: true

module Admin
  class ActivityDigest
    TTL = 5.minutes
    TOP = 12

    def initialize(days:, user: nil, now: Time.current)
      @days = days
      @user = user
      @now = now
    end

    def since = @since ||= (now - days.days).beginning_of_hour

    def per_user = digest[:per_user]

    def per_section = digest[:per_section]

    def per_day = digest[:per_day]

    def total = digest[:total]

    def events = scope.recent.includes(:user)

    private

    attr_reader :days, :user, :now

    def scope
      base = ActivityEvent.since(since)
      user ? base.where(user_id: user.id) : base
    end

    def digest
      @digest ||= Rails.cache.fetch(cache_key, expires_in: TTL) { compute }
    end

    def cache_key = ["admin/activity", days, user&.id, since.to_i].join("/")

    def compute
      by_day = scope.group(local_day).order(local_day).count.transform_keys(&:to_s)

      {
        per_user: with_emails(ranked(scope.group(:user_id))),
        per_section: ranked(scope.group(:controller)),
        per_day: by_day,
        total: by_day.values.sum
      }
    end

    def ranked(grouped) = grouped.order(Arel.sql("count(*) DESC")).limit(TOP).count

    def with_emails(counts)
      emails = User.where(id: counts.keys).pluck(:id, :email).to_h
      counts.filter_map { |id, count| [emails[id], count] if emails[id] }.to_h
    end

    def local_day
      @local_day ||= Arel.sql(
        ActivityEvent.sanitize_sql_array(
          ["date(created_at AT TIME ZONE 'UTC' AT TIME ZONE ?)", Time.zone.tzinfo.name]
        )
      )
    end
  end
end
