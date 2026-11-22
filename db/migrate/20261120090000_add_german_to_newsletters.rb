# frozen_string_literal: true

class AddGermanToNewsletters < ActiveRecord::Migration[8.1]
  def change
    change_table("newsletters", bulk: true) do |t|
      t.string("subject_de", default: "", null: false)
      t.string("preheader_de", default: "", null: false)
      t.text("body_de", default: "", null: false)
    end
  end
end
