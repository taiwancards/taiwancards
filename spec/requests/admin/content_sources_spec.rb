# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin content sources" do
  let(:admin) {
    User.create!(email: User.owner_google_email, password: "password123", google_email: User.owner_google_email)
  }
  let(:reader) { User.create!(email: "reader@example.com", password: "password123") }

  before do
    ContentSources::Importer.new.call
  end

  it "lists every source with its license for an admin" do
    sign_in(admin)
    get("/admin/content_sources")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("全國法規資料庫"))
    expect(response.body).to(include("Common Voice"))
    expect(response.body).to(include("OGDL"))
  end

  it "turns a source off for everyone" do
    source = ContentSource.find_by!(slug: "moj_law")
    sign_in(admin)

    patch("/admin/content_sources/#{source.id}", params: {content_source: {enabled: "0", enabled_for_admins: "1"}})

    expect(source.reload).not_to(be_enabled)
    expect(source).to(be_enabled_for_admins)
  end

  it "keeps non-admins out" do
    sign_in(reader)
    get("/admin/content_sources")
    expect(response).to(redirect_to(root_path))
  end
end
