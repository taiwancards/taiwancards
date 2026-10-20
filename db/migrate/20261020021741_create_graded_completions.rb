# frozen_string_literal: true

class CreateGradedCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table("graded_completions") do |t|
      t.references("user", null: false, index: false, foreign_key: {on_delete: :cascade})
      t.string("text_id", null: false)
      t.integer("score")
      t.integer("total")
      t.datetime("completed_at", null: false)
      t.timestamps
    end

    add_index("graded_completions", %w[user_id text_id], unique: true)
  end
end
