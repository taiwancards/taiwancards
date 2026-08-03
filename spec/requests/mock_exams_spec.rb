# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mock exams" do
  it "shows the band picker with a disclaimer and official links" do
    get("/mock")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("TOCFL emulation"))
    expect(response.body).to(include("tocfl.edu.tw"))
  end

  it "renders an empty-safe reading paper and grades it" do
    get("/mock/reading", params: {band: "novice", seed: 5})
    expect(response).to(have_http_status(:ok))

    post("/mock/reading", params: {band: "novice", seed: 5, answers: {}})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("0 / 0"))
  end
end
