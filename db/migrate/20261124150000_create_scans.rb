# frozen_string_literal: true

class CreateScans < ActiveRecord::Migration[8.1]
  def change
    create_table("scans") do |t|
      t.references("user", null: false, foreign_key: {on_delete: :cascade}, index: false)
      t.date("day", null: false)
      t.string("client_digest")
      t.integer("state", null: false, default: 0)
      t.boolean("counted", null: false, default: true)
      t.string("failure")
      t.string("legibility")
      t.text("text")
      t.string("changed_chars", array: true, null: false, default: [])
      t.string("model")
      t.integer("bytes", null: false)
      t.integer("width", null: false)
      t.integer("height", null: false)
      t.integer("input_tokens")
      t.integer("output_tokens")
      t.integer("latency_ms")
      t.datetime("started_at")
      t.datetime("finished_at")
      t.timestamps
    end

    add_index("scans", %w[user_id day])
    add_index("scans", %w[client_digest created_at], where: "client_digest IS NOT NULL")
    add_index("scans", "created_at")
    add_index("scans", "created_at", name: "index_scans_in_flight", where: "state IN (0, 1)")

    create_table("scan_pauses") do |t|
      t.string("reason", null: false)
      t.datetime("resumes_at", null: false)
      t.datetime("created_at", null: false)
    end

    add_index("scan_pauses", "resumes_at")
  end
end
