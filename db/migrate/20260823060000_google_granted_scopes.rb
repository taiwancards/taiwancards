# frozen_string_literal: true

class GoogleGrantedScopes < ActiveRecord::Migration[8.1]
  def change
    add_column("users", "google_scopes", :text)
  end
end
