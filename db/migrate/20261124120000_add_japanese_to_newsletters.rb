# frozen_string_literal: true

class AddJapaneseToNewsletters < ActiveRecord::Migration[8.1]
  def change
    change_table("newsletters", bulk: true) do |t|
      t.string("subject_ja", default: "", null: false)
      t.string("preheader_ja", default: "", null: false)
      t.text("body_ja", default: "", null: false)
    end
  end
end
