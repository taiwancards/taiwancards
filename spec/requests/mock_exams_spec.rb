# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mock exams" do
  it "shows the level picker with a disclaimer and official links" do
    get("/mock")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("TOCFL emulation"))
    expect(response.body).to(include("tocfl.edu.tw"))
    MockExam::Bank.levels.each do |level|
      expect(response.body).to(include("/mock/#{MockExam::Bank.slug(level)}"))
    end
  end

  it "lists picture and listening drills on the index" do
    get("/mock")

    expect(response.body).to(include("/mock/pictures"))
    expect(response.body).to(include("/mock/listening"))
    expect(response.body).to(include("not TOCFL formats"))
  end

  MockExam::Bank::LEVELS.each do |level|
    slug = MockExam::Bank.slug(level)

    it "renders a ten-question #{level} paper and grades a perfect run" do
      sheet = MockExam::Paper.build(level: level, seed: 7)
      expect(sheet.count).to(eq(10))

      get("/mock/#{slug}", params: {seed: 7})
      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("answers[10]"))

      answers = sheet.slots.to_h { |slot| [slot.number.to_s, slot.question.answer.to_s] }
      post("/mock/#{slug}", params: {seed: 7, answers: answers})

      expect(response).to(have_http_status(:ok))
      expect(response.body).to(include("10 / 10"))
    end
  end

  it "scores an empty submission as zero without raising" do
    post("/mock/a1", params: {seed: 3, answers: {}})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("0 / 10"))
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
        text: "我在車站等你。",
        level: 1,
        clip: "c.mp3",
        en: "I am waiting for you at the station.",
        ru: nil,
        emoji: "🚉",
        emoji_word: "車站",
        emoji_category: "place"
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
