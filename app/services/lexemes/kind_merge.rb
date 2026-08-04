# frozen_string_literal: true

module Lexemes
  class KindMerge
    KINDS = %i[word collocation].freeze
    OWNED = {
      "collection_items" => %w[collection_id position],
      "sentence_words" => %w[sentence_id gdex],
      "lexeme_content_sources" => %w[content_source_id created_at]
    }.freeze
    LOOSE = %w[lexeme_memories lexeme_reviews lexeme_senses sense_examples pronunciation_attempts].freeze

    Result = Data.define(:merged)

    def initialize(io: $stdout)
      @io = io
    end

    def call
      merged = duplicated.sum { |text| merge(text) }
      @io.puts("lexemes merged across word and collocation: #{merged}")
      Result.new(merged:)
    end

    def drift? = duplicated.any?

    private

    def duplicated
      Lexeme.where(kind: KINDS).group(:text).having("count(*) > 1").count.keys
    end

    def merge(text)
      rows = Lexeme.where(kind: KINDS, text: text).order(:id).to_a
      keeper = rows.shift
      return 0 if rows.empty?

      rows.each { |loser| absorb(keeper, loser) }
      keeper.save! if keeper.changed?
      rows.size
    end

    def absorb(keeper, loser)
      ActiveRecord::Base.transaction do
        OWNED.each { |table, keys| repoint(table, keys, keeper, loser) }
        LOOSE.each { |table| move(table, keeper, loser) }
        relink(keeper, loser)
        adopt(keeper, loser)
        loser.destroy!
      end
    end

    def repoint(table, keys, keeper, loser)
      columns = (keys + ["lexeme_id"]).join(", ")
      execute(
        "INSERT INTO #{table} (#{columns}) " \
          "SELECT #{keys.join(", ")}, #{keeper.id} FROM #{table} WHERE lexeme_id = #{loser.id} " \
          "ON CONFLICT DO NOTHING"
      )
      execute("DELETE FROM #{table} WHERE lexeme_id = #{loser.id}")
    end

    def move(table, keeper, loser)
      execute("UPDATE #{table} SET lexeme_id = #{keeper.id} WHERE lexeme_id = #{loser.id}")
    end

    def relink(keeper, loser)
      execute(
        "INSERT INTO lexeme_links (parent_id, child_id, position, reading) " \
          "SELECT #{keeper.id}, child_id, position, reading FROM lexeme_links WHERE parent_id = #{loser.id} " \
          "ON CONFLICT DO NOTHING"
      )
      execute("DELETE FROM lexeme_links WHERE parent_id = #{loser.id}")
      execute(
        "INSERT INTO lexeme_links (parent_id, child_id, position, reading) " \
          "SELECT parent_id, #{keeper.id}, position, reading FROM lexeme_links WHERE child_id = #{loser.id} " \
          "ON CONFLICT DO NOTHING"
      )
      execute("DELETE FROM lexeme_links WHERE child_id = #{loser.id}")
    end

    def adopt(keeper, loser)
      stale, fresh = [keeper, loser].sort_by(&:updated_at)
      keeper.readings = stale.readings.merge(fresh.readings.compact_blank)
      keeper.meanings = stale.meanings.merge(fresh.meanings.compact_blank)
      keeper.data = stale.data.merge(fresh.data.compact_blank)
      loser.sources.each { |source| keeper.add_source(source) }
      keeper.audio_url = loser.audio_url if keeper.audio_url.blank?
    end

    def execute(sql) = Lexeme.connection.execute(sql)
  end
end
