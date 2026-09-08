# frozen_string_literal: true

require "rails_helper"

RSpec.describe Deploy::ContentTables do
  let(:connection) { ActiveRecord::Base.connection }

  it "names only tables that exist, with keys that are real columns" do
    described_class::ORDERED.each do |table|
      expect(connection.table_exists?(table.name)).to(be(true), table.name)
      expect(connection.columns(table.name).map(&:name)).to(include(*table.key), "#{table.name} key")
    end
  end

  it "lists every parent before the tables that reference it" do
    names = described_class.names
    described_class::ORDERED.each do |table|
      connection.foreign_keys(table.name).each do |key|
        next unless names.include?(key.to_table)

        expect(names.index(key.to_table)).to(be < names.index(table.name), "#{table.name} references #{key.to_table}")
      end
    end
  end

  it "never carries a table that belongs to users" do
    described_class::ORDERED.each do |table|
      columns = connection.columns(table.name).map(&:name)
      next unless columns.include?("user_id")

      expect(table.scope).to(include("user_id IS NULL"), "#{table.name} must be scoped to system rows")
    end

    expect(described_class.names).not_to(include("users", "lexeme_memories", "lexeme_reviews", "activity_events"))
  end

  it "compares a wholesale-rebuilt table on its natural key" do
    words = described_class.find("sentence_words")

    expect(words.surrogate?).to(be(true))
    expect(words.key).to(eq(%w[sentence_id lexeme_id]))
  end
end
