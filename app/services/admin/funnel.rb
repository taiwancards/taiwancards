# frozen_string_literal: true

module Admin
  class Funnel
    WEEKS = 12
    COMMITTED_REVIEWS = 10
    SOURCES = 15

    Cohort = Data.define(:week, :size, :started, :studied, :committed, :day_one, :week_two, :month_two) do
      def mature?(offset, today: Date.current) = week + 6 + offset < today
    end

    Source = Data.define(:path, :signups, :studied)

    def initialize(now: Time.current)
      @now = now
    end

    def cohorts
      rows = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array(
          [
            <<~SQL
              WITH people AS (
                SELECT u.id, (u.prefs ? 'start_level' OR u.prefs ? 'goal') AS started,
                       MIN(d.day) AS first_day
                FROM users u JOIN user_days d ON d.user_id = u.id
                WHERE NOT u.admin AND u.created_at >= :since
                GROUP BY u.id
              ),
              first_reviews AS (
                SELECT r.user_id, COUNT(*) AS reviews
                FROM lexeme_reviews r JOIN people p ON p.id = r.user_id
                WHERE r.reviewed_on = p.first_day
                GROUP BY r.user_id
              ),
              returns AS (
                SELECT d.user_id,
                       BOOL_OR(d.day - p.first_day = 1) AS day_one,
                       BOOL_OR(d.day - p.first_day BETWEEN 7 AND 13) AS week_two,
                       BOOL_OR(d.day - p.first_day BETWEEN 30 AND 59) AS month_two
                FROM user_days d JOIN people p ON p.id = d.user_id
                GROUP BY d.user_id
              )
              SELECT DATE_TRUNC('week', p.first_day)::date AS week,
                     COUNT(*) AS size,
                     COUNT(*) FILTER (WHERE p.started) AS started,
                     COUNT(f.user_id) AS studied,
                     COUNT(*) FILTER (WHERE f.reviews >= :committed) AS committed,
                     COUNT(*) FILTER (WHERE r.day_one) AS day_one,
                     COUNT(*) FILTER (WHERE r.week_two) AS week_two,
                     COUNT(*) FILTER (WHERE r.month_two) AS month_two
              FROM people p
              LEFT JOIN first_reviews f ON f.user_id = p.id
              LEFT JOIN returns r ON r.user_id = p.id
              GROUP BY 1
              ORDER BY 1 DESC
            SQL
              .squish,
            {since: since, committed: COMMITTED_REVIEWS}
          ]
        )
      )

      rows.map { |row| Cohort.new(**row.symbolize_keys) }
    end

    def sources
      User
        .where(admin: false, created_at: since..)
        .group(Arel.sql("COALESCE(prefs->>'signup_from', '')"))
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(SOURCES)
        .pluck(
          Arel.sql("COALESCE(prefs->>'signup_from', '')"),
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM lexeme_reviews r WHERE r.user_id = users.id))")
        )
        .map { |path, signups, studied| Source.new(path:, signups:, studied:) }
    end

    private

    def since = (@now - WEEKS.weeks).beginning_of_week
  end
end
