# frozen_string_literal: true

require "rails_helper"

RSpec.describe "bin/rebuild-db-render.sh" do
  let(:script) { Rails.root.join("bin/rebuild-db-render.sh").read }

  it "verifies row counts only of tables the schema has" do
    tables = script[/^TABLES="(.*?)"/m, 1].to_s.split
    expect(tables).not_to(be_empty)

    missing = tables.reject { |table| ActiveRecord::Base.connection.table_exists?(table) }
    expect(missing).to(be_empty)
  end
end
