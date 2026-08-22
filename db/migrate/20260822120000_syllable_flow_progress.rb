# frozen_string_literal: true

class SyllableFlowProgress < ActiveRecord::Migration[8.1]
  def up
    add_column("syllable_skills", "ewma_flow", :float)
    add_column("syllable_skills", "n_flow", :integer, default: 0, null: false)
  end

  def down
    remove_column("syllable_skills", "n_flow")
    remove_column("syllable_skills", "ewma_flow")
  end
end
