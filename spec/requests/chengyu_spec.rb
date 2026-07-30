# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Idioms" do
  let!(:classic) do
    create(
      :lexeme,
      kind: :collocation,
      text: "一毛不拔",
      meanings: {"en" => "stingy"},
      score: 100,
      data: {
        "chengyu" => true,
        "chengyu_kind" => "classic",
        "chengyu_tone" => "negative",
        "chengyu_source" => "《孟子．盡心上》",
        "chengyu_story" => "楊朱的貴己學說……",
        "chengyu_examples" => ["他就像隻鐵公雞，一毛不拔。"],
        "chengyu_synonyms" => ["愛財如命"],
        "tbcl_grade" => "6"
      }
    )
  end

  let!(:colloquial) do
    create(
      :lexeme,
      kind: :collocation,
      text: "亂七八糟",
      meanings: {"en" => "a mess"},
      score: 900,
      data: {"chengyu" => true, "chengyu_kind" => "colloquial", "chengyu_tone" => "negative"}
    )
  end

  let!(:plain) do
    create(:lexeme, kind: :word, text: "學校", meanings: {"en" => "school"}, score: 10)
  end

  it "lists idioms and leaves ordinary entries out" do
    get("/chengyu")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("一毛不拔"))
    expect(response.body).to(include("亂七八糟"))
    expect(response.body).not_to(include("學校"))
  end

  it "filters by kind" do
    get("/chengyu", params: {kind: "classic"})
    expect(response.body).to(include("一毛不拔"))
    expect(response.body).not_to(include("亂七八糟"))
  end

  it "filters by school grade and separates what is beyond the syllabus" do
    get("/chengyu", params: {grade: "6"})
    expect(response.body).to(include("一毛不拔"))
    expect(response.body).not_to(include("亂七八糟"))

    get("/chengyu", params: {grade: "advanced"})
    expect(response.body).to(include("亂七八糟"))
    expect(response.body).not_to(include("一毛不拔"))
  end

  it "filters by difficulty band" do
    get("/chengyu", params: {band: "easy"})
    expect(response.body).to(include("一毛不拔"))
    expect(response.body).not_to(include("亂七八糟"))
  end

  it "shows origin, examples and synonyms on the entry page" do
    cookies["dict_detail"] = "full"
    get("/dict/#{CGI.escape("一毛不拔")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("《孟子．盡心上》"))
    expect(response.body).to(include(I18n.t("chengyu.examples")))
    expect(response.body).to(include("鐵"))
    expect(response.body).to(include("愛財如命"))
    expect(response.body).to(include("成語"))
  end
end
