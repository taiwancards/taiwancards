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
end
