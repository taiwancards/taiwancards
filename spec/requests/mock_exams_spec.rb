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

  it "lists picture and listening sections on the index" do
    get("/mock")

    expect(response.body).to(include("/mock/pictures"))
    expect(response.body).to(include("/mock/listening"))
  end

  it "renders and grades a pictures paper" do
    rows = [
      Huayu::ListeningClips::Row.new(
        text: "我去學校。",
        level: 1,
        clip: "a.mp3",
        en: "I go to school.",
        ru: nil,
        emoji: "🏫",
        emoji_word: "學校",
        emoji_category: "place"
      ),
      Huayu::ListeningClips::Row.new(
        text: "他在銀行。",
        level: 1,
        clip: "b.mp3",
        en: "He is at the bank.",
        ru: nil,
        emoji: "🏦",
        emoji_word: "銀行",
        emoji_category: "place"
      ),
      Huayu::ListeningClips::Row.new(
        text: "我要喝咖啡。",
        level: 2,
        clip: "c.mp3",
        en: "I want coffee.",
        ru: nil,
        emoji: "☕",
        emoji_word: "咖啡",
        emoji_category: "drink"
      )
    ]
    allow(Huayu::ListeningClips).to(receive(:with_emoji).and_return(rows))
    allow(Huayu::ListeningClips).to(receive(:pool).and_return(rows))

    get("/mock/pictures", params: {band: "novice", seed: 5})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("🏫"))

    post("/mock/pictures", params: {band: "novice", seed: 5, answers: {}})
    expect(response).to(have_http_status(:ok))

    get("/mock/listening", params: {band: "novice", seed: 5})
    expect(response).to(have_http_status(:ok))

    post("/mock/listening", params: {band: "novice", seed: 5, answers: {}})
    expect(response).to(have_http_status(:ok))
  end
end
