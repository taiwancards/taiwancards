# frozen_string_literal: true

class DropSlashedSpellings < ActiveRecord::Migration[8.1]
  ADDRESSABLE_KINDS = [0, 1, 2, 3, 5, 6, 8].freeze

  def up
    ids = select_values(
      <<~SQL
        SELECT l.id FROM lexemes l
        WHERE l.text LIKE '%/%'
          AND l.kind IN (#{ADDRESSABLE_KINDS.join(",")})
          AND NOT EXISTS (SELECT 1 FROM lexeme_memories m WHERE m.lexeme_id = l.id)
          AND NOT EXISTS (SELECT 1 FROM lexeme_reviews r WHERE r.lexeme_id = l.id)
          AND NOT EXISTS (SELECT 1 FROM pronunciation_attempts a WHERE a.lexeme_id = l.id)
      SQL
        .squish
    )

    return if ids.empty?

    list = ids.join(",")
    execute(
      <<~SQL
        DELETE FROM sense_examples
        WHERE lexeme_id IN (#{list})
           OR lexeme_sense_id IN (SELECT id FROM lexeme_senses WHERE lexeme_id IN (#{list}))
      SQL
        .squish
    )
    execute("DELETE FROM lexeme_senses WHERE lexeme_id IN (#{list})")
    execute("DELETE FROM lexeme_links WHERE parent_id IN (#{list}) OR child_id IN (#{list})")
    execute("DELETE FROM lexeme_content_sources WHERE lexeme_id IN (#{list})")
    execute("DELETE FROM sentence_profiles WHERE lexeme_id IN (#{list})")
    execute("DELETE FROM pronunciation_recordings WHERE lexeme_id IN (#{list})")
    execute("DELETE FROM lexemes WHERE id IN (#{list})")

    say("dropped #{ids.length} lexeme(s) whose text a route cannot address")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
