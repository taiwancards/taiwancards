# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Thesaurus" do
  let!(:target) do
    create(
      :lexeme,
      kind: :word,
      text: "高興",
      meanings: {"en" => "glad", "ru" => "радостный"},
      readings: {"pinyin" => "gāoxìng"},
      score: 30,
      data: {
        "synonyms" => %w[怡悅 快樂],
        "antonyms" => %w[傷心],
        "related" => %w[欣慰],
        "collocates" => %w[非常]
      }
    )
  end

  before do
    create(:lexeme, kind: :word, text: "快樂", meanings: {"en" => "happy"}, score: 40)
    create(:lexeme, kind: :word, text: "怡悅", meanings: {"en" => "joyful"}, score: 900)
    create(:lexeme, kind: :word, text: "傷心", meanings: {"en" => "heartbroken"}, score: 120)
    create(:lexeme, kind: :word, text: "欣慰", meanings: {"en" => "gratified"}, score: 300)
    create(:lexeme, kind: :word, text: "非常", meanings: {"en" => "very"}, score: 20)
  end

  it "shows every relation in its own group on the word page" do
    cookies["dict_detail"] = "full"
    get("/dict/#{CGI.escape("高興")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("thesaurus.synonyms")))
    expect(response.body).to(include(I18n.t("thesaurus.antonyms")))
    expect(response.body).to(include(I18n.t("thesaurus.related")))
    expect(response.body).to(include(I18n.t("thesaurus.collocates")))
    expect(response.body).to(include("快樂"))
    expect(response.body).to(include("傷心"))
  end

  it "keeps only synonyms and antonyms in the brief view" do
    cookies["dict_detail"] = "brief"
    get("/dict/#{CGI.escape("高興")}")

    expect(response.body).to(include(I18n.t("thesaurus.synonyms")))
    expect(response.body).to(include(I18n.t("thesaurus.antonyms")))
    expect(response.body).not_to(include(I18n.t("thesaurus.related")))
    expect(response.body).not_to(include(I18n.t("thesaurus.collocates")))
  end

  it "puts the frequent synonym before the rare one" do
    get("/dict/#{CGI.escape("高興")}")

    expect(response.body.index("快樂")).to(be < response.body.index("怡悅"))
  end

  it "leaves out a relation whose other side is not in the dictionary" do
    target.update!(data: target.data.merge("synonyms" => %w[快樂 黌舍]))

    get("/dict/#{CGI.escape("高興")}")

    expect(response.body).to(include("快樂"))
    expect(response.body).not_to(include("黌舍"))
  end

  it "shows nothing at all when the word has no relations" do
    plain = create(:lexeme, kind: :word, text: "書桌", meanings: {"en" => "desk"}, score: 50)

    get("/dict/#{CGI.escape(plain.text)}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).not_to(include(I18n.t("thesaurus.synonyms")))
    expect(response.body).not_to(include(I18n.t("thesaurus.collocates")))
  end
end
