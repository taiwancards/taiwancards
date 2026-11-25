# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Offline packs", :no_auth do
  it "opens the pack manager and the browser without an account" do
    %w[/offline /offline/browse].each do |path|
      get(path)

      expect(response).to(have_http_status(:ok), "expected #{path} to be open, got #{response.status}")
    end
  end

  it "serves the worker as javascript that browsers may revalidate" do
    raw_get("/sw.js")

    expect(response).to(have_http_status(:ok))
    expect(response.media_type).to(eq("text/javascript"))
    expect(response.headers["cache-control"]).to(include("must-revalidate"))
    expect(response.body).to(include("tc-fragments"))
  end

  it "answers the worker without a year of caching" do
    raw_get("/sw.js")

    expect(response.headers["cache-control"]).not_to(include("31536000"))
  end

  it "keeps a self-contained fallback page in every language without a session" do
    Locales::ALL.each do |code|
      raw_get("/#{code}/offline/fallback")

      expect(response).to(have_http_status(:ok))
      expect(response.headers["Set-Cookie"]).to(be_blank)
      expect(response.headers["cache-control"]).to(include("public", "s-maxage"))
      expect(response.body).to(include("<html lang=\"#{code}\"", "href=\"/#{code}/offline/browse\""))
      expect(response.body).not_to(include("<script", "stylesheet"))
    end
  end

  it "has the worker store the fallback for every language it knows" do
    raw_get("/sw.js")

    expect(response.body).to(include("/offline/fallback", "tc-fallback"))
    Locales::ALL.each { expect(response.body).to(include("\"#{it}\"")) }
  end
end
