# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2024_11_13_094358) do
  # These are extensions that must be enabled in order to support this database
  enable_extension("pg_catalog.plpgsql")
  enable_extension("pg_trgm")
  enable_extension("pgcrypto")

  create_table("activity_events", force: :cascade) do |t|
    t.string("action", null: false)
    t.string("controller", null: false)
    t.datetime("created_at", null: false)
    t.string("path", null: false)
    t.bigint("user_id")
    t.string("verb", null: false)
    t.index(["created_at"], name: "index_activity_events_on_created_at")
    t.index(["user_id", "created_at"], name: "index_activity_events_on_user_id_and_created_at")
  end

  create_table("collection_items", force: :cascade) do |t|
    t.bigint("collection_id", null: false)
    t.datetime("created_at", null: false)
    t.bigint("lexeme_id", null: false)
    t.integer("position", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.index(["collection_id", "lexeme_id"], name: "index_collection_items_on_collection_id_and_lexeme_id", unique: true)
    t.index(["lexeme_id"], name: "index_collection_items_on_lexeme_id")
  end

  create_table("collections", force: :cascade) do |t|
    t.datetime("created_at", null: false)
    t.text("description")
    t.integer("items_count", default: 0, null: false)
    t.integer("kind", default: 0, null: false)
    t.datetime("last_used_at")
    t.string("level_tag")
    t.string("name", null: false)
    t.integer("position", default: 0, null: false)
    t.jsonb("settings", default: {}, null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id")
    t.index(["name"], name: "index_collections_on_name_system", unique: true, where: "(user_id IS NULL)")
    t.index(["user_id", "name"], name: "index_collections_on_user_name", unique: true, where: "(user_id IS NOT NULL)")
  end

  create_table("content_sources", force: :cascade) do |t|
    t.text("attribution")
    t.integer("audio_count", default: 0, null: false)
    t.integer("collocations_count", default: 0, null: false)
    t.datetime("created_at", null: false)
    t.boolean("enabled", default: true, null: false)
    t.boolean("enabled_for_admins", default: true, null: false)
    t.boolean("license_commercial", default: false, null: false)
    t.boolean("license_derivatives", default: false, null: false)
    t.string("license_name")
    t.string("license_url")
    t.string("name", null: false)
    t.string("name_en")
    t.text("notes")
    t.integer("register")
    t.integer("sentences_count", default: 0, null: false)
    t.string("slug", null: false)
    t.boolean("statistics_only", default: false, null: false)
    t.boolean("style_sample", default: true, null: false)
    t.integer("translations_count", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.string("url")
    t.index(["enabled"], name: "index_content_sources_on_enabled")
    t.index(["slug"], name: "index_content_sources_on_slug", unique: true)
  end

  create_table("lexeme_content_sources", force: :cascade) do |t|
    t.bigint("content_source_id", null: false)
    t.datetime("created_at", null: false)
    t.bigint("lexeme_id", null: false)
    t.index(["content_source_id"], name: "index_lexeme_content_sources_on_content_source_id")
    t.index(["lexeme_id", "content_source_id"], name: "index_lexeme_sources_unique", unique: true)
  end

  create_table("lexeme_links", force: :cascade) do |t|
    t.bigint("child_id", null: false)
    t.bigint("parent_id", null: false)
    t.integer("position", default: 0, null: false)
    t.string("reading")
    t.index(["child_id", "reading"], name: "index_lexeme_links_on_child_id_and_reading")
    t.index(
      ["parent_id", "child_id", "position"],
      name: "index_lexeme_links_on_parent_id_and_child_id_and_position",
      unique: true
    )
    t.index(["parent_id", "position"], name: "index_lexeme_links_on_parent_id_and_position")
  end

  create_table("lexeme_memories", force: :cascade) do |t|
    t.datetime("activated_at")
    t.datetime("created_at", null: false)
    t.float("difficulty")
    t.datetime("due_at")
    t.integer("facet", default: 0, null: false)
    t.integer("lapses", default: 0, null: false)
    t.datetime("last_reviewed_at")
    t.bigint("lexeme_id", null: false)
    t.integer("reps", default: 0, null: false)
    t.float("stability")
    t.integer("state", default: 0, null: false)
    t.integer("step", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id")
    t.index(
      ["lexeme_id", "facet", "user_id"],
      name: "index_lexeme_memories_on_lexeme_id_and_facet_and_user_id",
      unique: true
    )
    t.index(
      ["user_id", "due_at"],
      name: "index_lexeme_memories_due",
      where: "((activated_at IS NOT NULL) AND (state <> 0))"
    )
    t.index(
      ["user_id", "state", "lexeme_id"],
      name: "index_lexeme_memories_activated",
      where: "(activated_at IS NOT NULL)"
    )
    t.index(["user_id"], name: "index_lexeme_memories_on_user_id")
  end

  create_table("lexeme_reviews", force: :cascade) do |t|
    t.float("difficulty_after")
    t.float("difficulty_before")
    t.datetime("due_after")
    t.float("elapsed_days")
    t.integer("elapsed_ms")
    t.integer("facet", default: 0, null: false)
    t.bigint("lexeme_id", null: false)
    t.bigint("lexeme_memory_id", null: false)
    t.integer("rating", null: false)
    t.datetime("reviewed_at", null: false)
    t.float("scheduled_days")
    t.uuid("session_id")
    t.float("stability_after")
    t.float("stability_before")
    t.integer("state_before")
    t.bigint("user_id")
    t.index(["lexeme_id", "reviewed_at"], name: "index_lexeme_reviews_on_lexeme_id_and_reviewed_at")
    t.index(["lexeme_memory_id"], name: "index_lexeme_reviews_on_lexeme_memory_id")
    t.index(["session_id"], name: "index_lexeme_reviews_on_session_id")
    t.index(["user_id", "reviewed_at"], name: "index_lexeme_reviews_on_user_id_and_reviewed_at")
  end

  create_table("lexeme_senses", force: :cascade) do |t|
    t.bigint("content_source_id")
    t.datetime("created_at", null: false)
    t.jsonb("data", default: {}, null: false)
    t.text("gloss_zh")
    t.bigint("lexeme_id", null: false)
    t.jsonb("meanings", default: {}, null: false)
    t.string("pos")
    t.integer("position", default: 0, null: false)
    t.string("reading")
    t.string("register")
    t.datetime("updated_at", null: false)
    t.index(["content_source_id"], name: "index_lexeme_senses_on_content_source_id")
    t.index(["lexeme_id", "position"], name: "index_lexeme_senses_on_lexeme_id_and_position", unique: true)
  end

  create_table("lexemes", force: :cascade) do |t|
    t.string("audio_url")
    t.datetime("created_at", null: false)
    t.jsonb("data", default: {}, null: false)
    t.virtual(
      "freq_rank",
      type: :integer,
      as: "\nCASE\n    WHEN ((data ->> 'freq_rank'::text) ~ '^-?[0-9]+$'::text) THEN ((data ->> 'freq_rank'::text))::integer\n    ELSE NULL::integer\nEND",
      stored: true
    )
    t.integer("kind", null: false)
    t.virtual(
      "level_index",
      type: :integer,
      as: "COALESCE(\nCASE (data ->> 'tocfl_level'::text)\n    WHEN 'Novice1'::text THEN 1\n    WHEN 'Novice2'::text THEN 2\n    WHEN 'A1'::text THEN 3\n    WHEN 'A2'::text THEN 4\n    WHEN 'B1'::text THEN 5\n    WHEN 'B2'::text THEN 6\n    WHEN 'C'::text THEN 7\n    ELSE NULL::integer\nEND,\nCASE\n    WHEN ((data ->> 'tbcl_grade'::text) ~ '^-?[0-9]+$'::text) THEN ((data ->> 'tbcl_grade'::text))::integer\n    ELSE NULL::integer\nEND)",
      stored: true
    )
    t.jsonb("meanings", default: {}, null: false)
    t.virtual(
      "moe_index",
      type: :integer,
      as: "\nCASE\n    WHEN ((data ->> 'moe_index'::text) ~ '^-?[0-9]+$'::text) THEN ((data ->> 'moe_index'::text))::integer\n    ELSE NULL::integer\nEND",
      stored: true
    )
    t.uuid("public_id")
    t.jsonb("readings", default: {}, null: false)
    t.boolean("restricted", default: false, null: false)
    t.float("score")
    t.text("search_text")
    t.jsonb("sources", default: [], null: false)
    t.integer("tbcl_at0", limit: 2, default: 99, null: false)
    t.virtual(
      "tbcl_grade",
      type: :integer,
      as: "\nCASE\n    WHEN ((data ->> 'tbcl_grade'::text) ~ '^[0-9]+$'::text) THEN ((data ->> 'tbcl_grade'::text))::integer\n    ELSE NULL::integer\nEND",
      stored: true
    )
    t.integer("tbcl_half", limit: 2, default: 99, null: false)
    t.integer("tbcl_third", limit: 2, default: 99, null: false)
    t.integer("tbcl_twothirds", limit: 2, default: 99, null: false)
    t.string("text", null: false)
    t.integer("tier", default: 0, null: false)
    t.integer("tocfl_at0", limit: 2, default: 99, null: false)
    t.integer("tocfl_half", limit: 2, default: 99, null: false)
    t.integer("tocfl_third", limit: 2, default: 99, null: false)
    t.integer("tocfl_twothirds", limit: 2, default: 99, null: false)
    t.datetime("updated_at", null: false)
    t.index(
      "(((data ->> 'radical_number'::text))::integer)",
      name: "index_lexemes_on_radical_number",
      where: "((kind = 0) AND ((data ->> 'radical_number'::text) ~ '^[0-9]+$'::text))"
    )
    t.index(
      "((data -> 'segments'::text))",
      name: "index_lexemes_on_sentence_segments",
      where: "(kind = 4)",
      using: :gin
    )
    t.index("((data ->> 'radical'::text))", name: "index_lexemes_on_radical", where: "(kind = 0)")
    t.index(
      "kind, ((data ->> 'chengyu_tone'::text)), ((data ->> 'chengyu_kind'::text)), ((data ->> 'tbcl_grade'::text))",
      name: "index_lexemes_chengyu_facets",
      where: "((data ->> 'chengyu'::text) = 'true'::text)"
    )
    t.index(
      "string_to_array(search_text, ' '::text)",
      name: "index_lexemes_on_search_tokens",
      where: "((kind <> 4) AND (search_text IS NOT NULL))",
      using: :gin
    )
    t.index(["kind", "freq_rank", "moe_index", "text"], name: "index_lexemes_frequency_order")
    t.index(["kind", "tbcl_grade"], name: "index_lexemes_on_kind_and_tbcl_grade")
    t.index(["kind", "text"], name: "index_lexemes_on_kind_and_text", unique: true)
    t.index(
      ["level_index", "freq_rank", "moe_index", "text"],
      name: "index_lexemes_chengyu_order",
      where: "((data ->> 'chengyu'::text) = 'true'::text)"
    )
    t.index(["public_id"], name: "index_lexemes_on_public_id", unique: true, where: "(public_id IS NOT NULL)")
    t.index(["restricted"], name: "index_lexemes_on_restricted", where: "restricted")
    t.index(["score"], name: "index_lexemes_on_score")
    t.index(
      ["search_text"],
      name: "index_lexemes_on_search_text",
      opclass: :gin_trgm_ops,
      where: "((kind <> 4) AND (search_text IS NOT NULL))",
      using: :gin
    )
    t.index(["sources"], name: "index_lexemes_on_sources", using: :gin)
    t.index(["tbcl_at0", "kind"], name: "index_lexemes_on_tbcl_at0")
    t.index(["tbcl_half", "kind"], name: "index_lexemes_on_tbcl_half")
    t.index(["tbcl_third", "kind"], name: "index_lexemes_on_tbcl_third")
    t.index(["tbcl_twothirds", "kind"], name: "index_lexemes_on_tbcl_twothirds")
    t.index(["text"], name: "index_lexemes_on_text", opclass: :gin_trgm_ops, where: "(kind <> 4)", using: :gin)
    t.index(["tier", "kind"], name: "index_lexemes_on_tier_and_kind")
    t.index(["tocfl_at0", "kind"], name: "index_lexemes_on_tocfl_at0")
    t.index(["tocfl_half", "kind"], name: "index_lexemes_on_tocfl_half")
    t.index(["tocfl_third", "kind"], name: "index_lexemes_on_tocfl_third")
    t.index(["tocfl_twothirds", "kind"], name: "index_lexemes_on_tocfl_twothirds")
  end

  create_table("mainland_markers", force: :cascade) do |t|
    t.boolean("active", default: true, null: false)
    t.datetime("created_at", null: false)
    t.integer("mainland_hits", default: 0, null: false)
    t.text("note")
    t.string("taiwan_form")
    t.integer("taiwan_hits", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.string("word", null: false)
    t.index(["active"], name: "index_mainland_markers_on_active")
    t.index(["word"], name: "index_mainland_markers_on_word", unique: true)
  end

  create_table("placement_tests", force: :cascade) do |t|
    t.jsonb("asked", default: [], null: false)
    t.datetime("created_at", null: false)
    t.integer("current_grade")
    t.jsonb("intake", default: {}, null: false)
    t.jsonb("pending", default: {}, null: false)
    t.jsonb("profile", default: {}, null: false)
    t.integer("result_grade")
    t.integer("seeded_count", default: 0, null: false)
    t.integer("status", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id", null: false)
    t.index(["user_id"], name: "index_placement_tests_on_user_id")
  end

  create_table("pronunciation_attempts", force: :cascade) do |t|
    t.string("best_match")
    t.datetime("created_at", null: false)
    t.string("level")
    t.bigint("lexeme_id", null: false)
    t.boolean("ok", default: false, null: false)
    t.string("recognized")
    t.boolean("rejected", default: false, null: false)
    t.integer("score_final")
    t.integer("score_initial")
    t.integer("score_medial")
    t.integer("score_overall")
    t.integer("score_syllable")
    t.integer("score_tone")
    t.integer("syllable_index", default: 0, null: false)
    t.string("syllable_key")
    t.bigint("user_id")
    t.index(["lexeme_id"], name: "index_pronunciation_attempts_on_lexeme_id")
    t.index(["user_id", "created_at"], name: "index_pronunciation_attempts_on_user_id_and_created_at")
    t.index(["user_id", "syllable_key", "created_at"], name: "idx_attempts_user_syllable_time")
  end

  create_table("reading_texts", force: :cascade) do |t|
    t.string("author")
    t.text("body", null: false)
    t.jsonb("body_data", default: {}, null: false)
    t.bigint("collection_id")
    t.bigint("content_source_id")
    t.datetime("created_at", null: false)
    t.integer("kind", default: 0, null: false)
    t.string("level_tag")
    t.boolean("restricted", default: false, null: false)
    t.string("source")
    t.string("source_url")
    t.string("title", null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id")
    t.index(["collection_id"], name: "index_reading_texts_on_collection_id")
    t.index(["content_source_id"], name: "index_reading_texts_on_content_source_id")
    t.index(["kind"], name: "index_reading_texts_on_kind")
    t.index(["restricted"], name: "index_reading_texts_on_restricted")
    t.index(["source_url"], name: "index_reading_texts_on_source_url", unique: true, where: "(source_url IS NOT NULL)")
    t.index(["user_id"], name: "index_reading_texts_on_user_id")
  end

  create_table("register_samples", force: :cascade) do |t|
    t.bigint("content_source_id", null: false)
    t.datetime("created_at", null: false)
    t.bigint("n", default: 0, null: false)
    t.string("text", null: false)
    t.datetime("updated_at", null: false)
    t.index(["content_source_id", "text"], name: "index_register_samples_unique", unique: true)
    t.index(["text"], name: "index_register_samples_on_text")
  end

  create_table("sense_examples", force: :cascade) do |t|
    t.bigint("content_source_id", null: false)
    t.datetime("created_at", null: false)
    t.integer("kind", default: 0, null: false)
    t.bigint("lexeme_id")
    t.bigint("lexeme_sense_id", null: false)
    t.integer("position", default: 0, null: false)
    t.text("text", null: false)
    t.datetime("updated_at", null: false)
    t.index(["content_source_id"], name: "index_sense_examples_on_content_source_id")
    t.index(["lexeme_id"], name: "index_sense_examples_on_lexeme_id")
    t.index(["lexeme_sense_id", "position"], name: "index_sense_examples_on_lexeme_sense_id_and_position")
  end

  create_table("sentence_profiles", force: :cascade) do |t|
    t.datetime("created_at", null: false)
    t.integer("difficulty", default: 0, null: false)
    t.boolean("freq_exact", default: false, null: false)
    t.integer("freq_index")
    t.integer("han_length", default: 0, null: false)
    t.bigint("lexeme_id", null: false)
    t.integer("registers", default: [], null: false, array: true)
    t.integer("source_ids", default: [], null: false, array: true)
    t.boolean("tbcl_exact", default: false, null: false)
    t.integer("tbcl_index")
    t.boolean("tocfl_exact", default: false, null: false)
    t.integer("tocfl_index")
    t.integer("unknown_count", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.index(["difficulty"], name: "index_sentence_profiles_on_difficulty")
    t.index(["freq_index", "difficulty"], name: "index_sentence_profiles_on_freq")
    t.index(["lexeme_id"], name: "index_sentence_profiles_on_lexeme_id", unique: true)
    t.index(["registers"], name: "index_sentence_profiles_on_registers", using: :gin)
    t.index(["source_ids"], name: "index_sentence_profiles_on_source_ids", using: :gin)
    t.index(["tbcl_index", "difficulty"], name: "index_sentence_profiles_on_tbcl")
    t.index(["tocfl_index", "difficulty"], name: "index_sentence_profiles_on_tocfl")
  end

  create_table("sentence_words", force: :cascade) do |t|
    t.integer("gdex", limit: 2, default: 0, null: false)
    t.bigint("lexeme_id", null: false)
    t.bigint("sentence_id", null: false)
    t.index(
      ["lexeme_id", "gdex"],
      name: "index_sentence_words_by_quality",
      order: {gdex: :desc},
      include: ["sentence_id"]
    )
    t.index(["sentence_id", "lexeme_id"], name: "index_sentence_words_unique", unique: true)
  end

  create_table("settings", force: :cascade) do |t|
    t.datetime("created_at", null: false)
    t.jsonb("data", default: {}, null: false)
    t.datetime("updated_at", null: false)
  end

  create_table("solid_cache_entries", force: :cascade) do |t|
    t.integer("byte_size", null: false)
    t.datetime("created_at", null: false)
    t.binary("key", null: false)
    t.bigint("key_hash", null: false)
    t.binary("value", null: false)
    t.index(["byte_size"], name: "index_solid_cache_entries_on_byte_size")
    t.index(["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size")
    t.index(["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true)
  end

  create_table("study_plans", force: :cascade) do |t|
    t.datetime("created_at", null: false)
    t.date("target_date", null: false)
    t.string("target_level", null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id", null: false)
    t.index(["user_id"], name: "index_study_plans_on_user_id_unique", unique: true)
  end

  create_table("syllable_skills", force: :cascade) do |t|
    t.integer("best", default: 0, null: false)
    t.datetime("created_at", null: false)
    t.integer("error_counts", default: [], null: false, array: true)
    t.float("ewma_final")
    t.float("ewma_initial")
    t.float("ewma_medial")
    t.float("ewma_overall")
    t.float("ewma_tone")
    t.datetime("first_seen_at")
    t.integer("heard_tones", default: [], null: false, array: true)
    t.datetime("last_seen_at")
    t.integer("n", default: 0, null: false)
    t.integer("n_amber", default: 0, null: false)
    t.integer("n_dark", default: 0, null: false)
    t.integer("n_green", default: 0, null: false)
    t.integer("n_red", default: 0, null: false)
    t.integer("recent", default: [], null: false, array: true)
    t.integer("streak", default: 0, null: false)
    t.string("syllable", null: false)
    t.string("syllable_key", null: false)
    t.integer("tone", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id", null: false)
    t.integer("z_n", default: [], null: false, array: true)
    t.float("z_sum", default: [], null: false, array: true)
    t.index(["user_id", "syllable_key"], name: "index_syllable_skills_on_user_id_and_syllable_key", unique: true)
  end

  create_table("textbook_lessons", force: :cascade) do |t|
    t.integer("book", null: false)
    t.datetime("created_at", null: false)
    t.integer("lesson", null: false)
    t.text("summary_html")
    t.text("summary_html_ru")
    t.string("title_en", null: false)
    t.string("title_ru")
    t.string("title_zh")
    t.datetime("updated_at", null: false)
    t.jsonb("vocabulary", default: [], null: false)
    t.index(["book", "lesson"], name: "index_textbook_lessons_on_book_and_lesson", unique: true)
  end

  create_table("users", force: :cascade) do |t|
    t.boolean("admin", default: false, null: false)
    t.datetime("created_at", null: false)
    t.string("email", null: false)
    t.datetime("email_verified_at")
    t.text("google_access_token")
    t.string("google_email")
    t.text("google_refresh_token")
    t.datetime("google_token_expires_at")
    t.string("google_uid")
    t.string("locale", default: "en", null: false)
    t.string("name")
    t.string("password_digest", null: false)
    t.jsonb("prefs", default: {}, null: false)
    t.boolean("restricted_content", default: false, null: false)
    t.datetime("updated_at", null: false)
    t.index("lower((email)::text)", name: "index_users_on_lower_email", unique: true)
    t.index(["google_uid"], name: "index_users_on_google_uid", unique: true, where: "(google_uid IS NOT NULL)")
  end

  create_table("voice_profiles", force: :cascade) do |t|
    t.datetime("calibrated_at")
    t.string("calibration_locale")
    t.datetime("created_at", null: false)
    t.string("declared_gender")
    t.jsonb("f0_by_tone", default: {}, null: false)
    t.integer("f0_hist", default: [], array: true)
    t.float("f1_ref")
    t.float("f2_ref")
    t.float("f3_ref")
    t.integer("n_attempts", default: 0, null: false)
    t.integer("n_calibration_frames", default: 0, null: false)
    t.datetime("updated_at", null: false)
    t.bigint("user_id", null: false)
    t.index(["user_id"], name: "index_voice_profiles_on_user_id", unique: true)
  end

  add_foreign_key("activity_events", "users")
  add_foreign_key("collection_items", "collections")
  add_foreign_key("collection_items", "lexemes")
  add_foreign_key("collections", "users")
  add_foreign_key("lexeme_content_sources", "content_sources")
  add_foreign_key("lexeme_content_sources", "lexemes")
  add_foreign_key("lexeme_links", "lexemes", column: "child_id")
  add_foreign_key("lexeme_links", "lexemes", column: "parent_id")
  add_foreign_key("lexeme_memories", "lexemes")
  add_foreign_key("lexeme_memories", "users")
  add_foreign_key("lexeme_reviews", "lexeme_memories")
  add_foreign_key("lexeme_reviews", "lexemes")
  add_foreign_key("lexeme_reviews", "users")
  add_foreign_key("lexeme_senses", "content_sources")
  add_foreign_key("lexeme_senses", "lexemes")
  add_foreign_key("placement_tests", "users")
  add_foreign_key("pronunciation_attempts", "lexemes")
  add_foreign_key("pronunciation_attempts", "users")
  add_foreign_key("reading_texts", "collections")
  add_foreign_key("reading_texts", "content_sources")
  add_foreign_key("reading_texts", "users")
  add_foreign_key("register_samples", "content_sources", on_delete: :cascade)
  add_foreign_key("sense_examples", "content_sources")
  add_foreign_key("sense_examples", "lexeme_senses")
  add_foreign_key("sense_examples", "lexemes")
  add_foreign_key("sentence_profiles", "lexemes")
  add_foreign_key("sentence_words", "lexemes", column: "sentence_id", on_delete: :cascade)
  add_foreign_key("sentence_words", "lexemes", on_delete: :cascade)
  add_foreign_key("study_plans", "users")
  add_foreign_key("syllable_skills", "users")
  add_foreign_key("voice_profiles", "users")
end
