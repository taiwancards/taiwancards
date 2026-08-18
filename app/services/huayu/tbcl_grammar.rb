# frozen_string_literal: true

module Huayu
  class TbclGrammar
    DATA = JsonData.new("huayu/tbcl_grammar_points.json", default: [], watch: true)
    SOURCE_SLUG = "naer_tbcl"
    TIERS = %w[基礎 進階].freeze

    Point = Data.define(:id, :pattern, :tier, :level, :starred) do
      def starred? = starred
    end

    class << self
      def all = table

      def find(id) = by_id[id.to_i]

      def tiers = table.map(&:tier).uniq.sort_by { |tier| TIERS.index(tier) || TIERS.length }

      def size = table.length

      def starred_count = table.count(&:starred?)

      def available? = table.any?

      def source = ContentSource.find_by(slug: SOURCE_SLUG)

      def reset!
        DATA.reset!
        remove_instance_variable(:@table) if defined?(@table)
        remove_instance_variable(:@by_id) if defined?(@by_id)
      end

      private

      def table
        @table ||= DATA.value.map do |row|
          Point.new(
            id: row["id"].to_i,
            pattern: row["pattern"].to_s,
            tier: row["tier"].to_s,
            level: row["level"].to_i,
            starred: row["starred"] == true
          )
        end
      end

      def by_id = @by_id ||= table.index_by(&:id)
    end
  end
end
