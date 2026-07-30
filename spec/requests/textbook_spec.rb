# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Textbook" do
  before { Rails.application.load_seed }
  before { sign_in(create(:user, restricted_content: true)) }

  let!(:textbook_lesson) do
    TextbookLesson.create!(
      book: 1,
      lesson: 1,
      title_en: "Welcome!",
      title_zh: "歡迎！",
      title_ru: "Добро пожаловать!",
      summary_html: "<h2>Key Grammar</h2><p>English text</p>",
      summary_html_ru: "<h2>Ключевая грамматика</h2><p>Русский текст</p>",
      vocabulary: [
        {
          "name" => "B1L01-01",
          "traditional" => "謝謝",
          "pinyin" => "xièxie",
          "meaning" => "thank you",
          "meaning_ru" => "спасибо",
          "category" => "V",
          "audio" => "B1L01-01.mp3"
        }
      ]
    )
  end

  it "lists books and lessons" do
    get("/textbook")
    expect(response.body).to(include("Welcome!").and(include("歡迎！")))
  end

  it "shows the lesson summary in the current locale" do
    get("/textbook/1/1")
    expect(response.body).to(include("Key Grammar").and(include("謝")))

    sign_in(create(:user, locale: "ru", restricted_content: true))
    get("/textbook/1/1")
    expect(response.body).to(include("Ключевая грамматика").and(include("спасибо")))
  end
end
