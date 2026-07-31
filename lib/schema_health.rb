# frozen_string_literal: true

class SchemaHealth
  def initialize(connection: ActiveRecord::Base.connection)
    @connection = connection
  end

  def unindexed_foreign_keys
    connection.tables.flat_map do |table|
      leading = leading_columns(table)
      connection.foreign_keys(table).filter_map { |key| "#{table}.#{key.column}" unless leading.include?(key.column) }
    end
  end

  private

  attr_reader :connection

  def leading_columns(table)
    indexed = connection.indexes(table).map { |index| index.columns.is_a?(Array) ? index.columns.first : nil }
    (indexed + [Array(connection.primary_keys(table)).first]).compact.to_set
  end
end
