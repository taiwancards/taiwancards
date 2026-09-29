# frozen_string_literal: true

class Newsletters < ActiveRecord::Migration[8.1]
  def up
    create_table("newsletters") do |t|
      t.string("subject_en", default: "", null: false)
      t.string("subject_ru", default: "", null: false)
      t.string("preheader_en", default: "", null: false)
      t.string("preheader_ru", default: "", null: false)
      t.text("body_en", default: "", null: false)
      t.text("body_ru", default: "", null: false)
      t.jsonb("buttons", default: [], null: false)
      t.datetime("sent_at")
      t.timestamps
    end

    create_table("newsletter_images") do |t|
      t.bigint("newsletter_id", null: false)
      t.string("content_type", null: false)
      t.string("filename", null: false)
      t.binary("data", null: false)
      t.integer("byte_size", null: false)
      t.timestamps
      t.index("newsletter_id", name: "index_newsletter_images_on_newsletter_id")
    end

    create_table("newsletter_deliveries") do |t|
      t.bigint("newsletter_id", null: false)
      t.bigint("user_id", null: false)
      t.string("locale", null: false)
      t.datetime("sent_at")
      t.string("error")
      t.datetime("clicked_at")
      t.integer("clicks_count", default: 0, null: false)
      t.datetime("unsubscribed_at")
      t.timestamps
      t.index(%w[newsletter_id user_id], unique: true, name: "index_newsletter_deliveries_on_newsletter_and_user")
      t.index("user_id", name: "index_newsletter_deliveries_on_user_id")
      t.index("sent_at", name: "index_newsletter_deliveries_on_sent_at")
    end

    add_column("users", "newsletter_unsubscribed_at", :datetime)

    add_foreign_key("newsletter_images", "newsletters", on_delete: :cascade)
    add_foreign_key("newsletter_deliveries", "newsletters", on_delete: :cascade)
    add_foreign_key("newsletter_deliveries", "users", on_delete: :cascade)
  end

  def down
    remove_column("users", "newsletter_unsubscribed_at")
    drop_table("newsletter_deliveries")
    drop_table("newsletter_images")
    drop_table("newsletters")
  end
end
