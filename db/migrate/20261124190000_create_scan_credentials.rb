# frozen_string_literal: true

class CreateScanCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table("scan_credentials") do |t|
      t.text("secret")
      t.string("hint")
      t.datetime("set_at")
      t.date("expires_on")
      t.date("expiry_warned_on")
      t.string("state", null: false, default: "unchecked")
      t.string("checked_digest")
      t.datetime("checked_at")
      t.datetime("rejected_at")
      t.string("model")
      t.timestamps
    end

    add_check_constraint("scan_credentials", "id = 1", name: "scan_credentials_single_row")
    add_check_constraint(
      "scan_credentials",
      "state IN ('unchecked', 'ok', 'rejected')",
      name: "scan_credentials_state"
    )
  end
end
