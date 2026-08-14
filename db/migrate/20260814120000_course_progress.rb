# frozen_string_literal: true

class CourseProgress < ActiveRecord::Migration[8.1]
  def up
    create_table("course_completions") do |t|
      t.bigint("user_id", null: false)
      t.string("slug", null: false)
      t.integer("score", default: 0, null: false)
      t.integer("total", default: 0, null: false)
      t.datetime("completed_at")
      t.timestamps
      t.index(%w[user_id slug], name: "index_course_completions_on_user_and_slug", unique: true)
    end

    add_foreign_key("course_completions", "users", on_delete: :cascade)
  end

  def down
    drop_table("course_completions")
  end
end
