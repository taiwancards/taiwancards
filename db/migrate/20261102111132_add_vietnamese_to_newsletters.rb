# frozen_string_literal: true

class AddVietnameseToNewsletters < ActiveRecord::Migration[8.1]
  def change
    change_table("newsletters", bulk: true) do |t|
      t.string("subject_vi", default: "", null: false)
      t.string("preheader_vi", default: "", null: false)
      t.text("body_vi", default: "", null: false)
    end
  end
end
