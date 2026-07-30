# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Handwriting and stroke data" do
  it "renders the handwriting recognizer page" do
    get("/handwriting")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("data-controller=\"handwriting\""))
  end

  describe "stroke data endpoint", if: Huayu::StrokeData.available? do
    it "serves hanzi-writer stroke JSON for a known character" do
      get("/characters/#{CGI.escape("一")}/strokes")
      expect(response).to(have_http_status(:ok))
      data = JSON.parse(response.body)
      expect(data["strokes"]).to(be_an(Array).and(be_present))
      expect(data["medians"]).to(be_an(Array).and(be_present))
    end

    it "returns 404 for a character with no stroke data" do
      get("/characters/#{CGI.escape("𠀀")}/strokes")
      expect(response).to(have_http_status(:not_found))
    end
  end
end
