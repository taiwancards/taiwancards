# frozen_string_literal: true

module Lexemes
  class Activator
    def initialize(now: Time.current)
      @now = now
    end

    def call(lexeme)
      facets = Lexemes::Facets.for(lexeme)
      facets.map { |facet| activate(lexeme, facet) }
    end

    def call_many(lexemes)
      lexemes = Array(lexemes)
      return 0 if lexemes.empty?

      wanted = lexemes.flat_map do |lexeme|
        Lexemes::Facets.for(lexeme).map { |facet| [lexeme.id, LexemeMemory.facets.fetch(facet)] }
      end

      insert(wanted - already_active(wanted))
    end

    def activate(lexeme, facet)
      memory = LexemeMemory.find_or_initialize_by(lexeme:, facet: LexemeMemory.facets[facet], user: Current.user)
      memory.activated_at ||= @now
      memory.save! if memory.changed?
      memory
    end

    private

    def already_active(wanted)
      return [] if wanted.empty?

      LexemeMemory
        .owned_by(Current.user)
        .where(lexeme_id: wanted.map(&:first).uniq)
        .where
        .not(activated_at: nil)
        .pluck(:lexeme_id, :facet)
        .map { |lexeme_id, facet| [lexeme_id, LexemeMemory.facets.fetch(facet)] }
    end

    def insert(pairs)
      return 0 if pairs.empty?

      rows = pairs.map do |lexeme_id, facet|
        {
          lexeme_id: lexeme_id,
          facet: facet,
          user_id: Current.user&.id,
          activated_at: @now,
          created_at: @now,
          updated_at: @now
        }
      end

      LexemeMemory.upsert_all(rows, unique_by: %i[lexeme_id facet user_id], record_timestamps: false)
      rows.length
    end
  end
end
