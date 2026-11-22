# frozen_string_literal: true

class AddIndonesianToNewsletters < ActiveRecord::Migration[8.1]
  def change
    change_table("newsletters", bulk: true) do |t|
      t.string("subject_ind", default: "", null: false)
      t.string("preheader_ind", default: "", null: false)
      t.text("body_ind", default: "", null: false)
    end
  end
end
