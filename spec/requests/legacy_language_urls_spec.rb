# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy zh-TW urls" do
  it "sends the bare language root to the desk" do
    get("/zh-TW")

    expect(response).to(redirect_to("/en/desk"))
  end

  it "strips the language segment from a plain page" do
    get("/zh-TW/tones")

    expect(response).to(redirect_to("/en/tones"))
  end

  it "keeps nested segments intact" do
    get("/zh-TW/textbook/1/2")

    expect(response).to(redirect_to("/en/textbook/1/2"))
  end

  it "survives a percent-encoded chinese word" do
    get("/zh-TW/words/#{CGI.escape("立陶宛")}")

    expect(response).to(redirect_to("/en/words/#{CGI.escape("立陶宛")}"))
  end

  it "does not shadow the routes it redirects to" do
    get("/tones")

    expect(response).to(have_http_status(:ok))
  end
end
