# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Practice basics" do
  it "renders the basics hub" do
    get("/practice")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("practice.phonetics_title")))
  end

  it "folds the old pinyin route into the single phonetics page" do
    get("/practice/pinyin")
    expect(response).to(redirect_to(practice_zhuyin_path))
  end

  it "opens on the introduction, before any table" do
    get("/practice/zhuyin")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("practice.why_title")))
    expect(response.body).not_to(include("IPA"))
  end

  it "renders the initials table with zhuyin, IPA and examples" do
    get("/practice/zhuyin", params: {part: "initials"})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("ㄅ", "IPA"))
  end

  it "renders the finals table" do
    get("/practice/zhuyin", params: {part: "finals"})
    expect(response.body).to(include("ㄤ"))
  end

  it "ends the last part with a link into the drill" do
    get("/practice/zhuyin", params: {part: "tricky"})
    expect(response.body).to(include(practice_drill_path))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("practice.to_drill"))))
  end

  it "falls back to the introduction for an unknown part" do
    get("/practice/zhuyin", params: {part: "nonsense"})
    expect(response.body).to(include(I18n.t("practice.why_title")))
  end

  it "keeps the drill free of the theory that moved to the chart" do
    get("/practice/drill")
    expect(response.body).not_to(include(I18n.t("practice.drill.syllable_title")))
    expect(response.body).not_to(include(I18n.t("practice.drill.mismatch_more_title")))
  end

  it "renders the zhuyin reference" do
    get("/practice/zhuyin")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("ㄆ"))
  end

  it "renders the practice progress page and reflects recorded attempts" do
    lexeme = create(:lexeme, kind: :word, text: "學校")
    SyllableSkill.claim(Current.user, "xue2").record!(
      overall: 44,
      level: "red",
      parts: {"tone" => 44},
      heard: "xue3"
    )

    get("/practice/progress")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("By tone", "Most-confused"))
  end

  it "sends the reader straight from the initials table into drilling them" do
    get("/practice/zhuyin", params: {part: "initials"})

    expect(response.body).to(include(zhuyin_training_path(group: "initials")))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("practice.practice_now.initials"))))
  end

  it "sends the finals table into its own drill, not the initials one" do
    get("/practice/zhuyin", params: {part: "finals"})

    expect(response.body).to(include(zhuyin_training_path(group: "finals")))
    expect(response.body).not_to(include(zhuyin_training_path(group: "initials")))
  end

  it "keeps the pinyin bridge for the tricky-cases section only" do
    get("/practice/zhuyin", params: {part: "tricky"})
    expect(response.body).to(include(practice_drill_path))

    get("/practice/zhuyin", params: {part: "initials"})
    expect(response.body).not_to(include(CGI.escapeHTML(I18n.t("practice.to_drill"))))
  end

  it "drills only the section it was scoped to" do
    get("/practice/zhuyin-trainer", params: {group: "finals"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("zhuyin_trainer.scoped.finals"))))
    expect(response.body).to(include(I18n.t("zhuyin_trainer.blocks.medial")))
    expect(response.body).not_to(include(I18n.t("zhuyin_trainer.blocks.labial")))
  end

  it "counts progress against the scoped set, not all 37" do
    get("/practice/zhuyin-trainer", params: {group: "finals"})

    expect(response.body).to(include(I18n.t("zhuyin_trainer.progress", done: 0, total: 16)))
  end
end
