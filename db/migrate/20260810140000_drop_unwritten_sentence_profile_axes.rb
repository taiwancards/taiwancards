# frozen_string_literal: true

class DropUnwrittenSentenceProfileAxes < ActiveRecord::Migration[8.1]
  COLUMNS = %i[mediums productions formalities purposes].freeze

  def up
    COLUMNS.each { |column| remove_column(:sentence_profiles, column) }
  end

  def down
    COLUMNS.each do |column|
      add_column(:sentence_profiles, column, :integer, array: true, default: [], null: false)
      add_index(:sentence_profiles, column, using: :gin)
    end
  end
end
