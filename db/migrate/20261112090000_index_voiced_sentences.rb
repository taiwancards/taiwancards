# frozen_string_literal: true

class IndexVoicedSentences < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  NAME = "index_lexemes_on_voiced_sentences"

  def up
    add_index(
      :lexemes,
      :id,
      name: NAME,
      where: "kind = #{Lexeme.kinds.fetch("sentence")} AND NOT restricted AND data ? 'audio'",
      algorithm: :concurrently,
      if_not_exists: true
    )
  end

  def down
    remove_index(:lexemes, name: NAME, if_exists: true, algorithm: :concurrently)
  end
end
