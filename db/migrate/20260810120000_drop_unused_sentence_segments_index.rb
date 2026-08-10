# frozen_string_literal: true

class DropUnusedSentenceSegmentsIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  NAME = "index_lexemes_on_sentence_segments"

  def up
    remove_index(:lexemes, name: NAME, if_exists: true, algorithm: :concurrently)
  end

  def down
    add_index(
      :lexemes,
      "((data -> 'segments'::text))",
      name: NAME,
      where: "(kind = #{Lexeme.kinds.fetch("sentence")})",
      using: :gin,
      algorithm: :concurrently
    )
  end
end
