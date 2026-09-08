# frozen_string_literal: true

module Deploy
  module ContentTables
    Table = Data.define(:name, :key, :scope, :surrogate) do
      def predicate = scope || "TRUE"

      def bucket = key.first

      def surrogate? = surrogate

      def sequenced? = key == %w[id]
    end

    SYSTEM_COLLECTIONS = "user_id IS NULL"
    SYSTEM_COLLECTION_ITEMS = "collection_id IN (SELECT id FROM collections WHERE user_id IS NULL)"

    ORDERED = [
      ["content_sources", %w[id], nil, false],
      ["lexemes", %w[id], nil, false],
      ["china_markers", %w[id], nil, false],
      ["textbook_lessons", %w[id], nil, false],
      ["collections", %w[id], SYSTEM_COLLECTIONS, false],
      ["lexeme_links", %w[id], nil, false],
      ["lexeme_senses", %w[id], nil, false],
      ["lexeme_content_sources", %w[id], nil, false],
      ["register_samples", %w[id], nil, false],
      ["sentence_profiles", %w[id], nil, false],
      ["sense_examples", %w[id], nil, false],
      ["sentence_words", %w[sentence_id lexeme_id], nil, true],
      ["collection_items", %w[collection_id lexeme_id], SYSTEM_COLLECTION_ITEMS, false]
    ].map { |name, key, scope, surrogate| Table.new(name:, key:, scope:, surrogate:) }.freeze

    ALL = ORDERED.map(&:name).freeze

    BOOKKEEPING = %w[settings solid_cache_entries ar_internal_metadata schema_migrations].freeze

    USER_TABLES = %w[
      users
      lexeme_memories
      lexeme_reviews
      pronunciation_attempts
      pronunciation_recordings
      syllable_skills
      voice_profiles
      reading_texts
      study_plans
      placement_tests
      activity_events
      collection_groups
      collection_group_items
      course_completions
      deck_shares
    ]
      .freeze

    USER_REFERENCES = {
      "lexeme_reviews" => "lexeme_id",
      "lexeme_memories" => "lexeme_id",
      "pronunciation_attempts" => "lexeme_id"
    }.freeze

    module_function

    def names = ALL

    def find(name)
      ORDERED.find { |table| table.name == name } || raise(ArgumentError, "#{name} is not a content table")
    end
  end
end
