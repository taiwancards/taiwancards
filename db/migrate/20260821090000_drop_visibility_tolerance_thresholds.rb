# frozen_string_literal: true

class DropVisibilityToleranceThresholds < ActiveRecord::Migration[8.1]
  SCALES = %w[tbcl tocfl].freeze
  STEPS = %w[at0 third half twothirds].freeze

  def up
    columns.each { |column| remove_column(:lexemes, column) }
  end

  def down
    columns.each do |column|
      add_column(:lexemes, column, :integer, limit: 2, default: 99, null: false)
      add_index(:lexemes, [column, :kind], name: "index_lexemes_on_#{column}")
    end
  end

  def columns
    SCALES.flat_map { |scale| STEPS.map { |step| :"#{scale}_#{step}" } }
  end
end
