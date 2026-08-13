# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Phrase drills" do
  def drill(text, position, en: "meaning", ru: "перевод", difficulty: 100, score: nil, **extra)
    create(
      :lexeme,
      kind: :phrase,
      text:,
      restricted: true,
      score: score || position,
      meanings: {"en" => en, "ru" => ru},
      data: {"drill" => position, "difficulty" => difficulty}.merge(extra.transform_keys(&:to_s)),
      sources: [Huayu::PhraseDrillsImporter::SOURCE]
    )
  end

  def book_sentence(text, en: "meaning", score: 1)
    create(
      :lexeme,
      kind: :phrase,
      text:,
      restricted: true,
      score:,
      meanings: {"en" => en},
      data: {"sentence" => true, "difficulty" => 100},
      sources: ["Textbook B1L01"]
    )
  end

  context("for the owner") do
    before { sign_in(create(:user, :admin, restricted_content: true)) }

    it "lists the easiest sentences first" do
      drill("你好嗎？", 1, en: "How are you?", score: 800)
      drill("我好餓。", 2, en: "I'm so hungry.", score: 20)

      get("/textbook/phrases")

      expect(response).to(have_http_status(:ok))
      expect(response.body.index("I&#39;m so hungry.")).to(be < response.body.index("How are you?"))
    end

    it "shows the internal score next to every sentence" do
      drill("我好餓。", 1, score: 42.4)

      get("/textbook/phrases")

      expect(response.body).to(include(">42<"))
    end

    it "shows the translation in the interface language" do
      drill("我好餓。", 1, ru: "Я так проголодался.")

      get("/ru/textbook/phrases")

      expect(response.body).to(include("Я так проголодался."))
    end

    it "offers the tab below the textbook one" do
      get("/textbook/phrases")

      expect(response.body).to(include(I18n.t("nav.phrase_drills")))
    end

    it "lists the textbook sentences alongside the drills and labels where each came from" do
      drill("我好餓。", 1, en: "I'm so hungry.")
      book_sentence("你好嗎？", en: "How are you?")

      get("/textbook/phrases")

      expect(response.body).to(include("I&#39;m so hungry."))
      expect(response.body).to(include("How are you?"))
      expect(response.body).to(include(">GL<"))
      expect(response.body).to(include(">DA<"))
    end

    it "filters by where the sentence came from" do
      drill("我好餓。", 1, en: "I'm so hungry.")
      book_sentence("你好嗎？", en: "How are you?")

      get("/textbook/phrases", params: {book: "DA"})

      expect(response.body).to(include("How are you?"))
      expect(response.body).not_to(include("I&#39;m so hungry."))
    end

    it "filters by difficulty level" do
      drill("我好餓。", 1, difficulty: 50, en: "I'm so hungry.")
      drill("迪米特里在超市。", 2, difficulty: 750, en: "Dmitry is at the supermarket.")

      get("/textbook/phrases", params: {level: "1"})

      expect(response.body).to(include("I&#39;m so hungry."))
      expect(response.body).not_to(include("Dmitry is at the supermarket."))
    end

    it "searches inside the section by hanzi and by translation" do
      drill("我好餓。", 1, en: "I'm so hungry.", ru: "Я голоден.")
      drill("你好嗎？", 2, en: "How are you?", ru: "Как дела?")

      get("/textbook/phrases", params: {q: "餓"})
      expect(response.body).to(include("I&#39;m so hungry."))
      expect(response.body).not_to(include("How are you?"))

      get("/ru/textbook/phrases", params: {q: "дела"})
      expect(response.body).to(include("Как дела?"))
      expect(response.body).not_to(include("Я голоден."))
    end

    it "shows the curriculum grade and filters by it" do
      drill("我好餓。", 1, en: "I'm so hungry.", tbcl: 2, tbcl_exact: true)
      drill("你好嗎？", 2, en: "How are you?", tbcl: 6, tbcl_exact: false)

      get("/textbook/phrases")
      expect(response.body).to(include("TBCL 2"))
      expect(response.body).to(include("TBCL 6*"))

      get("/textbook/phrases", params: {scheme: "tbcl", grade: "2"})
      expect(response.body).to(include("I&#39;m so hungry."))
      expect(response.body).not_to(include("How are you?"))
    end

    it "offers both curriculum grade lists without waiting for a round trip" do
      drill("我好餓。", 1)

      get("/textbook/phrases")

      expect(response.body).to(include("data-scheme=\"tocfl\""))
      expect(response.body).to(include("data-scheme=\"tbcl\""))
    end

    it "leaves the readings to the header switch" do
      drill("我好餓。", 1)

      get("/textbook/phrases")

      expect(response.body).to(include("py-line"))
      expect(response.body).not_to(include("reading-hints"))
    end

    it "pages through a long list" do
      (PhraseDrillsController::PER_PAGE + 1).times { |index|
        drill("第#{index}句。", index + 1, en: "line #{index}")
      }

      get("/textbook/phrases")
      expect(response.body).not_to(include("line #{PhraseDrillsController::PER_PAGE}"))

      get("/textbook/phrases", params: {page: 2})
      expect(response.body).to(include("line #{PhraseDrillsController::PER_PAGE}"))
    end

    it "marks every word as a tappable dictionary lookup with its readings" do
      create(
        :lexeme,
        kind: :word,
        text: "晚餐",
        readings: {"zhuyin" => "ㄨㄢˇ ㄘㄢ", "pinyin" => "wǎncān"},
        data: {"readings" => [{"zhuyin" => "ㄨㄢˇ ㄘㄢ", "pinyin" => "wǎncān"}]}
      )
      Huayu::TextAnalyzer.reset_vocabulary!
      drill("晚餐。", 1)

      get("/textbook/phrases")

      expect(response.body).to(include("data-analyzer-target=\"word\""))
      expect(response.body).to(include("ㄨㄢˇ"))
      expect(response.body).to(include("wǎncān"))
    ensure
      Huayu::TextAnalyzer.reset_vocabulary!
    end
  end

  it "turns a regular account away" do
    drill("我好餓。", 1)
    sign_in(create(:user))

    get("/textbook/phrases")

    expect(response).to(redirect_to("/en"))
  end

  it "sends a guest to the login", :no_auth do
    get("/textbook/phrases")

    expect(response).to(redirect_to(login_path))
  end

  it "shows no phrases tab to a regular account" do
    sign_in(create(:user))

    get("/desk")

    expect(response.body).not_to(include("/textbook/phrases"))
  end
end
