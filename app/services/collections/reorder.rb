# frozen_string_literal: true

module Collections
  class Reorder
    MAX_ITEMS = 2_000

    def self.call(scope, ordered_ids, key: :id)
      column = scope.klass.column_names.find { |name| name == key.to_s }
      raise ArgumentError, "unknown column" if column.nil?

      ids = Array(ordered_ids).map(&:to_i).reject(&:zero?).uniq.first(MAX_ITEMS)
      return 0 if ids.empty?

      present = scope.where(column => ids).pluck(column)
      return 0 if present.empty?

      scope.where(column => present).update_all(Arel.sql(assignment(column, ids, present)))
    end

    def self.assignment(column, ids, present)
      ranked = ids.each_with_index.to_h
      quoted = ActiveRecord::Base.connection.quote_column_name(column)
      branches = present.map { |id| "WHEN #{id.to_i} THEN #{ranked.fetch(id).to_i}" }
      "position = CASE #{quoted} #{branches.join(" ")} END"
    end

    private_class_method :assignment
  end
end
