# frozen_string_literal: true

class PronunciationRecordings < ActiveRecord::Migration[8.1]
  def up
    create_table("pronunciation_recordings") do |t|
      t.bigint("user_id", null: false)
      t.bigint("lexeme_id")
      t.string("text", null: false)
      t.string("syllable_keys", default: [], null: false, array: true)
      t.jsonb("syllables", default: [], null: false)
      t.jsonb("expected", default: [], null: false)
      t.binary("audio", null: false)
      t.string("content_type")
      t.integer("verdict", default: 0, null: false)
      t.integer("rejected_indices", default: [], null: false, array: true)
      t.string("note")
      t.datetime("rated_at")
      t.timestamps
      t.index(%w[verdict created_at], name: "index_pronunciation_recordings_on_verdict_and_time")
      t.index("user_id", name: "index_pronunciation_recordings_on_user_id")
      t.index("lexeme_id", name: "index_pronunciation_recordings_on_lexeme_id")
    end

    add_foreign_key("pronunciation_recordings", "users", on_delete: :cascade)
    add_foreign_key("pronunciation_recordings", "lexemes", on_delete: :nullify)
  end

  def down
    drop_table("pronunciation_recordings")
  end
end
