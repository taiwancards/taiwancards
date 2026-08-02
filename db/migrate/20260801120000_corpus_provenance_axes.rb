# frozen_string_literal: true

class CorpusProvenanceAxes < ActiveRecord::Migration[8.1]
  AXES = {medium: :mediums, production: :productions, formality: :formalities, purpose: :purposes}.freeze

  def change
    AXES.each_key { |axis| add_column(:content_sources, axis, :integer) }
    add_index(:content_sources, :production)

    AXES.each_value do |column|
      add_column(:sentence_profiles, column, :integer, array: true, default: [], null: false)
      add_index(:sentence_profiles, column, using: :gin)
    end

    add_column(:mainland_markers, :band, :integer, default: 0, null: false)
    add_index(:mainland_markers, %i[band active])
  end
end
