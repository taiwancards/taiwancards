# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA", :no_auth do
  it "serves the web app manifest without a session" do
    get(pwa_manifest_path)

    expect(response).to(have_http_status(:ok))
  end

  it "describes the application for the install prompt" do
    get(pwa_manifest_path)
    manifest = JSON.parse(response.body)

    expect(manifest["name"]).to(eq("TaiwanCards"))
    expect(manifest["short_name"]).to(be_present)
    expect(manifest["description"]).to(be_present)
    expect(manifest["start_url"]).to(eq("/"))
    expect(manifest["display"]).to(eq("standalone"))
  end

  it "ships an icon big enough for a home-screen tile, including a maskable one" do
    get(pwa_manifest_path)
    icons = JSON.parse(response.body).fetch("icons")

    expect(icons).to(include(hash_including("sizes" => "512x512")))
    expect(icons).to(include(hash_including("purpose" => "maskable")))
  end

  it "is linked from the layout so browsers can find it" do
    sign_in
    get(root_path)

    expect(response.body).to(include("rel=\"manifest\""))
  end
end
