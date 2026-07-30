# frozen_string_literal: true

module Deploy
  module ContentTables
    ALL = %w[
      content_sources
      mainland_markers
      lexemes
      lexeme_links
      lexeme_content_sources
      lexeme_senses
      sense_examples
      sentence_profiles
      sentence_words
      textbook_lessons
      collections
      collection_items
    ]
      .freeze

    INCREMENTAL = {
      "lexemes" => "rake deploy:push",
      "textbook_lessons" => "rails textbook:load on the server",
      "lexeme_senses" => "gloss fillers on the server",
      "sense_examples" => "gloss fillers on the server",
      "content_sources" => "huayu:import_sources"
    }.freeze

    USER_TABLES = %w[
      users
      lexeme_memories
      lexeme_reviews
      pronunciation_attempts
      syllable_skills
      voice_profiles
      reading_texts
      study_plans
      placement_tests
      activity_events
    ]
      .freeze

    def self.full_dump_only = ALL - INCREMENTAL.keys
  end
end
