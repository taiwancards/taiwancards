# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Measure words" do
  let!(:noun) do
    create(
      :lexeme,
      kind: :word,
      text: "貓",
      meanings: {"en" => "cat", "ru" => "кошка"},
      readings: {"pinyin" => "māo"},
      score: 20,
      data: {"classifiers" => [{"text" => "隻", "count" => 33, "sources" => %w[cedict corpus], "main" => true}]}
    )
  end

  let!(:character) do
    create(:lexeme, kind: :character, text: "隻", meanings: {"en" => "single"}, score: 90)
  end

  let!(:entry) do
    create(
      :lexeme,
      kind: :measure_word,
      text: "隻",
      readings: {"pinyin" => "zhī", "zhuyin" => "ㄓ"},
      meanings: {"en" => "Counts animals", "ru" => "Считает животных"},
      score: 30,
      data: {
        "category" => "individual",
        "nouns" => ["貓"],
        "usage" => 699,
        "moe_gloss" => "量詞。計算動物的單位。"
      }
    )
  end

  let!(:other) do
    create(
      :lexeme,
      kind: :measure_word,
      text: "公斤",
      readings: {"pinyin" => "gōngjīn"},
      meanings: {"en" => "Kilogram"},
      score: 500,
      data: {"category" => "measurement", "usage" => 40}
    )
  end

  it "lists measure words grouped by what they count" do
    get("/liangci")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("隻"))
    expect(response.body).to(include("公斤"))
    expect(response.body).to(include(I18n.t("liangci.categories.individual")))
  end

  it "filters by category" do
    get("/liangci", params: {category: "measurement"})

    expect(response.body).to(include(liangci_entry_path(text: "公斤")))
    expect(response.body).not_to(include(liangci_entry_path(text: "隻")))
  end

  it "shows the nouns a measure word counts" do
    cookies["dict_detail"] = "full"
    get("/liangci/#{CGI.escape("隻")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("貓"))
    expect(response.body).to(include("量詞。計算動物的單位。"))
    expect(response.body).to(include(I18n.t("liangci.as_character")))
  end

  it "quotes sentences where the measure word really counts, and highlights the phrase" do
    source = ContentSource.find_by(slug: "corpus") ||
      ContentSource.create!(
        slug: "corpus",
        license_commercial: true,
        name: "Corpus",
        register: :colloquial,
        enabled: true,
        enabled_for_admins: true,
        attribution: "Corpus."
      )
    sentence = create(
      :lexeme,
      kind: :sentence,
      text: "我家有兩隻貓。",
      score: 5,
      content_sources: [source]
    )
    SentenceWord.create!(lexeme: noun, sentence_id: sentence.id, gdex: 500)

    get("/liangci/#{CGI.escape("隻")}")

    expect(response.body).to(include("兩隻貓"))
    expect(response.body).to(include(I18n.t("liangci.examples")))
  end

  it "answers with a not-found page for a word that is not a measure word" do
    get("/liangci/#{CGI.escape("學校")}")

    expect(response).to(have_http_status(:not_found))
    expect(response.body).to(include(I18n.t("liangci.not_found")))
  end

  it "keeps the old measure-words addresses working" do
    get("/measure-words")
    expect(response).to(redirect_to("/en/liangci"))

    get("/measure-words/#{CGI.escape("隻")}")
    expect(response).to(redirect_to("/en/liangci/#{ERB::Util.url_encode("隻")}"))
  end

  it "shows the same pair on the noun page as on the measure word page" do
    get("/dict/#{CGI.escape("貓")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("liangci.for_noun")))
    expect(response.body).to(include("隻"))
  end

  it "spells out the official part of speech instead of its code" do
    noun.update!(data: noun.data.merge("pos" => "N"))

    get("/dict/#{CGI.escape("貓")}")

    expect(response.body).to(include(I18n.t("pos.tocfl.n")))
    expect(response.body).not_to(match(/>\s*N\s*</))
  end

  it "marks a character that also works as a measure word" do
    get("/characters/#{CGI.escape("隻")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("liangci.as_measure_word")))
  end

  it "offers a round of the game with reading and meaning on every card" do
    get("/liangci/game")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("貓"))
    expect(response.body).to(include("māo"))
  end
end
