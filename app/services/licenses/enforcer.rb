# frozen_string_literal: true

module Licenses
  class Enforcer
    DEPENDENTS = [
      ["collection_items", "lexeme_id"],
      ["lexeme_content_sources", "lexeme_id"],
      ["lexeme_memories", "lexeme_id"],
      ["lexeme_reviews", "lexeme_id"],
      ["lexeme_senses", "lexeme_id"],
      ["pronunciation_attempts", "lexeme_id"],
      ["sense_examples", "lexeme_id"],
      ["sentence_profiles", "lexeme_id"],
      ["lexeme_links", "child_id"],
      ["lexeme_links", "parent_id"]
    ].freeze

    SCRATCH = "licence_purge"

    UNCOVERED = <<~SQL
      NOT EXISTS (
        SELECT 1 FROM lexeme_content_sources link
        JOIN content_sources source ON source.id = link.content_source_id
        WHERE link.lexeme_id = lexemes.id AND source.license_commercial AND NOT source.statistics_only
      )
    SQL
      .squish

    def self.uncovered = Lexeme.where(kind: :sentence).where(UNCOVERED)

    def initialize(io: $stdout)
      @io = io
    end

    def call
      stage
      total = connection.select_value("SELECT count(*) FROM #{SCRATCH}").to_i
      removed = total.zero? ? 0 : purge
      counts = ContentSource.measurement_only.update_all(sentences_count: 0)
      connection.execute("DROP TABLE IF EXISTS #{SCRATCH}")

      {sentences_dropped: removed, sources_reset: counts, sentences_left: Lexeme.where(kind: :sentence).count}
    end

    private

    def connection = Lexeme.connection

    def stage
      connection.execute("DROP TABLE IF EXISTS #{SCRATCH}")
      connection.execute("CREATE TEMP TABLE #{SCRATCH} AS #{self.class.uncovered.select(:id).to_sql}")
      connection.execute("CREATE UNIQUE INDEX ON #{SCRATCH} (id)")
      connection.execute("ANALYZE #{SCRATCH}")
    end

    def purge
      DEPENDENTS.each do |table, column|
        connection.execute("DELETE FROM #{table} WHERE #{column} IN (SELECT id FROM #{SCRATCH})")
      end

      connection.exec_delete("DELETE FROM lexemes WHERE id IN (SELECT id FROM #{SCRATCH})")
    end
  end
end
