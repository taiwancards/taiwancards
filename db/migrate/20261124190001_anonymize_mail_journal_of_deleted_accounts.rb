# frozen_string_literal: true

class AnonymizeMailJournalOfDeletedAccounts < ActiveRecord::Migration[8.1]
  def up
    change_column_null("mail_events", "email", true)
    execute(
      <<~SQL
        UPDATE mail_events
        SET email = NULL,
          detail = CASE event
            WHEN 'failed' THEN COALESCE(substring(detail FROM '^[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*'), '')
            WHEN 'scheduled' THEN regexp_replace(detail, '^([^|]*[|][^|]*)[|].*$', '\\1')
            ELSE detail
          END
        WHERE user_id IS NULL AND email IS NOT NULL AND list <> 'alerts'
      SQL
        .squish
    )
  end

  def down = raise ActiveRecord::IrreversibleMigration
end
