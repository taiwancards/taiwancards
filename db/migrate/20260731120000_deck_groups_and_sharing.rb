# frozen_string_literal: true

class DeckGroupsAndSharing < ActiveRecord::Migration[8.1]
  def up
    remove_column("collection_items", "created_at")
    remove_column("collection_items", "updated_at")
    remove_index("collection_items", name: "index_collection_items_on_collection_id_and_lexeme_id")
    remove_index("collection_items", name: "index_collection_items_on_lexeme_id")
    remove_column("collection_items", "id")
    execute("ALTER TABLE collection_items ADD PRIMARY KEY (collection_id, lexeme_id)")
    add_index("collection_items", %w[lexeme_id], name: "index_collection_items_on_lexeme_id")

    remove_foreign_key("collection_items", "collections")
    remove_foreign_key("collection_items", "lexemes")
    add_foreign_key("collection_items", "collections", on_delete: :cascade)
    add_foreign_key("collection_items", "lexemes", on_delete: :cascade)

    add_index(
      "collections",
      %w[user_id position id],
      name: "index_collections_on_user_position",
      where: "user_id IS NOT NULL AND kind = 0"
    )

    create_table("collection_groups") do |t|
      t.bigint("user_id", null: false)
      t.string("name", null: false)
      t.integer("position", default: 0, null: false)
      t.integer("collections_count", default: 0, null: false)
      t.timestamps
      t.index(%w[user_id name], name: "index_collection_groups_on_user_name", unique: true)
      t.index(%w[user_id position id], name: "index_collection_groups_on_user_position")
    end

    create_table("collection_group_items", primary_key: %w[collection_group_id collection_id]) do |t|
      t.bigint("collection_group_id", null: false)
      t.bigint("collection_id", null: false)
      t.integer("position", default: 0, null: false)
      t.index(
        %w[collection_group_id position],
        name: "index_collection_group_items_on_group_and_position",
        include: %w[collection_id]
      )
      t.index(%w[collection_id collection_group_id], name: "index_collection_group_items_on_collection_id")
    end

    create_table("deck_shares") do |t|
      t.bigint("user_id", null: false)
      t.string("token", null: false)
      t.integer("kind", default: 0, null: false)
      t.string("name", null: false)
      t.integer("decks_count", default: 1, null: false)
      t.integer("cards_count", default: 0, null: false)
      t.integer("accepted_count", default: 0, null: false)
      t.jsonb("payload", default: {}, null: false)
      t.datetime("expires_at")
      t.datetime("revoked_at")
      t.timestamps
      t.index(%w[token], name: "index_deck_shares_on_token", unique: true)
      t.index(%w[user_id created_at], name: "index_deck_shares_on_user_id_and_created_at")
    end

    add_foreign_key("collection_groups", "users", on_delete: :cascade)
    add_foreign_key("collection_group_items", "collection_groups", on_delete: :cascade)
    add_foreign_key("collection_group_items", "collections", on_delete: :cascade)
    add_foreign_key("deck_shares", "users", on_delete: :cascade)
  end

  def down
    drop_table("deck_shares")
    drop_table("collection_group_items")
    drop_table("collection_groups")

    remove_index("collections", name: "index_collections_on_user_position")

    remove_foreign_key("collection_items", "collections")
    remove_foreign_key("collection_items", "lexemes")
    remove_index("collection_items", name: "index_collection_items_on_lexeme_id")
    execute("ALTER TABLE collection_items DROP CONSTRAINT collection_items_pkey")
    add_column("collection_items", "id", :primary_key)
    add_column("collection_items", "created_at", :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" })
    add_column("collection_items", "updated_at", :datetime, null: false, default: -> { "CURRENT_TIMESTAMP" })
    change_column_default("collection_items", "created_at", from: -> { "CURRENT_TIMESTAMP" }, to: nil)
    change_column_default("collection_items", "updated_at", from: -> { "CURRENT_TIMESTAMP" }, to: nil)
    add_index(
      "collection_items",
      %w[collection_id lexeme_id],
      name: "index_collection_items_on_collection_id_and_lexeme_id",
      unique: true
    )
    add_index("collection_items", %w[lexeme_id], name: "index_collection_items_on_lexeme_id")
    add_foreign_key("collection_items", "collections")
    add_foreign_key("collection_items", "lexemes")
  end
end
