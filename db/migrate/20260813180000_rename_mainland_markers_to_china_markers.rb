# frozen_string_literal: true

class RenameMainlandMarkersToChinaMarkers < ActiveRecord::Migration[8.1]
  def change
    rename_table(:mainland_markers, :china_markers)
    rename_column(:china_markers, :mainland_hits, :china_hits)
  end
end
