# frozen_string_literal: true

module Lexemes
  class HokkienIndex
    KEY = "hokkien"

    Result = Data.define(:reindexed) do
      def to_s = "hokkien search index rebuilt: #{reindexed}"
    end

    def call
      rows = pending
      rows.each { |lexeme| lexeme.update_column(:search_text, lexeme.search_text) }
      Result.new(reindexed: rows.length)
    end

    def drift? = pending.any?

    private

    def pending
      @pending ||= scope.select do |lexeme|
        lexeme.rebuild_search_text
        lexeme.search_text_changed?
      end
    end

    def scope
      Lexeme.where.not(kind: :sentence).where("data ? :key", key: KEY)
    end
  end
end
