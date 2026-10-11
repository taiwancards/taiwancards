# frozen_string_literal: true

class RetentionAndOutreach < ActiveRecord::Migration[8.1]
  def up
    create_table("user_days", primary_key: %w[user_id day]) do |t|
      t.bigint("user_id", null: false)
      t.date("day", null: false)
    end

    add_index("user_days", "day")
    add_foreign_key("user_days", "users", on_delete: :cascade)

    add_column("users", "reminders_off_at", :datetime)

    create_table("reminder_deliveries") do |t|
      t.bigint("user_id", null: false)
      t.string("trigger", null: false)
      t.integer("count", default: 0, null: false)
      t.string("path", null: false)
      t.string("locale", null: false)
      t.datetime("sent_at")
      t.datetime("clicked_at")
      t.string("error")
      t.timestamps
    end

    add_index("reminder_deliveries", %w[user_id created_at])
    add_index("reminder_deliveries", "created_at")
    add_foreign_key("reminder_deliveries", "users", on_delete: :cascade)

    create_table("page_views") do |t|
      t.date("day", null: false)
      t.string("path", null: false)
      t.string("locale", null: false, default: "")
      t.string("source", null: false, default: "")
      t.string("device", null: false, default: "")
      t.string("country", null: false, default: "")
      t.integer("views", null: false, default: 0)
    end

    add_index(
      "page_views",
      %w[day path locale source device country],
      unique: true,
      name: "index_page_views_on_dimensions"
    )

    add_column("newsletters", "audience", :jsonb, default: {}, null: false)

    create_table("mail_events") do |t|
      t.bigint("user_id")
      t.string("email", null: false)
      t.string("list", null: false)
      t.string("event", null: false)
      t.string("letter", null: false, default: "")
      t.string("source", null: false, default: "")
      t.string("detail", null: false, default: "")
      t.integer("count")
      t.text("summary", null: false, default: "")
      t.datetime("created_at", null: false)
    end

    add_index("mail_events", %w[user_id created_at])
    add_index("mail_events", "created_at")
    add_foreign_key("mail_events", "users", on_delete: :nullify, on_update: :cascade)

    create_table("mail_links") do |t|
      t.bigint("user_id", null: false)
      t.string("token_digest", null: false)
      t.string("kind", null: false)
      t.string("list", null: false)
      t.string("letter", null: false, default: "")
      t.string("target", null: false, default: "")
      t.string("delivery_type")
      t.bigint("delivery_id")
      t.integer("clicks_count", null: false, default: 0)
      t.datetime("used_at")
      t.datetime("created_at", null: false)
    end

    add_index("mail_links", "token_digest", unique: true)
    add_index("mail_links", "user_id")
    add_index("mail_links", %w[delivery_type delivery_id])
    add_foreign_key("mail_links", "users", on_delete: :cascade, on_update: :cascade)

    backfill_user_days
    backfill_mail_events
  end

  def down
    drop_table("mail_links", if_exists: true)
    drop_table("mail_events", if_exists: true)
    remove_column("newsletters", "audience")
    drop_table("page_views")
    drop_table("reminder_deliveries")
    remove_column("users", "reminders_off_at")
    drop_table("user_days")
  end

  private

  def backfill_user_days
    zone = connection.quote(Rails.application.config.time_zone)
    execute(
      <<~SQL
        INSERT INTO user_days (user_id, day)
        SELECT DISTINCT user_id, reviewed_on FROM lexeme_reviews WHERE user_id IS NOT NULL
        UNION
        SELECT DISTINCT e.user_id, DATE(e.created_at AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(u.time_zone, #{zone}))
        FROM activity_events e JOIN users u ON u.id = e.user_id
        UNION
        SELECT id, DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE COALESCE(time_zone, #{zone})) FROM users
        ON CONFLICT DO NOTHING
      SQL
        .squish
    )
  end

  def backfill_mail_events
    execute(
      <<~SQL
        INSERT INTO mail_events (user_id, email, list, event, letter, source, detail, summary, created_at)
        SELECT d.user_id, u.email, 'newsletter', e.event,
               CASE WHEN d.locale = 'ru' THEN n.subject_ru ELSE n.subject_en END, e.source, e.detail,
               CASE WHEN e.event = 'sent' THEN LEFT(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(
                 CASE WHEN d.locale = 'ru' THEN n.subject_ru || '. ' || n.body_ru ELSE n.subject_en || '. ' || n.body_en END,
                 '<[^>]+>', ' ', 'g'), '\\s+', ' ', 'g')), 600) ELSE '' END,
               e.at
        FROM newsletter_deliveries d
        JOIN users u ON u.id = d.user_id
        JOIN newsletters n ON n.id = d.newsletter_id
        CROSS JOIN LATERAL (
          VALUES ('sent', '', '', d.sent_at),
                 ('failed', '', COALESCE(d.error, ''), CASE WHEN d.sent_at IS NULL AND d.error IS NOT NULL THEN d.updated_at END),
                 ('clicked', '', '', d.clicked_at),
                 ('unsubscribed', 'email_link', '', d.unsubscribed_at)
        ) AS e(event, source, detail, at)
        WHERE e.at IS NOT NULL
        UNION ALL
        SELECT u.id, u.email, 'newsletter', 'unsubscribed', '', 'profile', '', '', u.newsletter_unsubscribed_at
        FROM users u
        WHERE u.newsletter_unsubscribed_at IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM newsletter_deliveries d WHERE d.user_id = u.id AND d.unsubscribed_at IS NOT NULL)
      SQL
        .squish
    )
  end
end
