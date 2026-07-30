# frozen_string_literal: true

module Huayu
  class TocflReadiness
    Stat = Data.define(:collection, :total, :started, :known) do
      def readiness
        total.zero? ? 0 : (known * 100.0 / total).round
      end
    end

    COUNTS = <<~SQL
      SELECT items.collection_id AS collection_id,
             count(DISTINCT memories.lexeme_id)
               FILTER (WHERE memories.activated_at IS NOT NULL) AS started,
             count(DISTINCT memories.lexeme_id)
               FILTER (WHERE memories.state = :review) AS known
      FROM collection_items items
      JOIN lexeme_memories memories ON memories.lexeme_id = items.lexeme_id
      WHERE items.collection_id IN (:collections)
        AND memories.user_id IS NOT DISTINCT FROM :user
      GROUP BY items.collection_id
    SQL
      .squish

    def levels
      build(Collection.where(kind: :tocfl).order(:position).to_a)
    end

    def stat(collection)
      build([collection]).first
    end

    private

    def build(collections)
      counted = counts_for(collections.map(&:id))
      collections.map do |collection|
        row = counted[collection.id] || {}
        Stat.new(
          collection: collection,
          total: collection.items_count,
          started: row["started"].to_i,
          known: row["known"].to_i
        )
      end
    end

    def counts_for(ids)
      return {} if ids.empty?

      sql = ActiveRecord::Base.sanitize_sql_array(
        [
          COUNTS,
          {collections: ids, user: Current.user&.id, review: LexemeMemory.states[:review]}
        ]
      )

      ActiveRecord::Base.connection.select_all(sql).index_by { |row| row["collection_id"] }
    end
  end
end
