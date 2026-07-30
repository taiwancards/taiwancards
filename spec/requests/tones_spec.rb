# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tones" do
  it "explains why tones matter rather than only listing them" do
    get("/tones")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("tones.why_title")))
    expect(response.body).to(include(I18n.t("tones.myth_title")))
    expect(response.body).to(include(I18n.t("tones.cannot_title")))
  end

  it "describes all four tones and charts them" do
    get("/tones")

    %w[t1 t2 t3 t4].each do |key|
      expect(response.body).to(include(I18n.t("tones.tones.#{key}.name")))
      expect(response.body).to(include(ToneChartHelper::CONTOURS["beijing"][key][:label]))
    end
  end

  it "puts Taipei before Beijing" do
    get("/tones")

    expect(response.body.index(I18n.t("tones.chart.taipei")))
      .to(be < response.body.index(I18n.t("tones.chart.beijing")))
  end

  it "quotes prescriptive figures for Beijing but invents none for Taipei" do
    expect(ToneChartHelper::CONTOURS["beijing"].values.map { |c| c[:label] }).to(all(be_present))
    expect(ToneChartHelper::CONTOURS["taipei"].values.map { |c| c[:label] }).to(all(be_nil))
  end

  it "lists every documented Taiwanese difference, not just one" do
    get("/tones")

    %w[range second third neutral erhua merge].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.taiwan_points.#{key}"))))
    end
  end

  it "covers the segmental differences as well as the tonal ones" do
    get("/tones")

    expect(response.body).to(include(I18n.t("tones.segments_title")))
    %w[retroflex nasal].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.segments.#{key}"))))
    end
  end

  it "draws the charts as inline svg, with no external image to license" do
    get("/tones")

    expect(response.body).to(include("<svg"))
    expect(response.body).not_to(match(/<img[^>]+wikimedia/i))
  end

  it "gives the practical hacks, including that the third tone is simply low" do
    get("/tones")

    expect(response.body).to(include(I18n.t("tones.hacks_title")))
    %w[low pair start after_third fourth relative neutral].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.hacks.#{key}"))))
    end
  end

  it "keeps the drill on its own page so nothing plays unbidden" do
    get("/tones")
    expect(response.body).not_to(include("tone-drill"))
    expect(response.body).to(include(tones_drill_path))

    get("/tones/drill")
    expect(response).to(have_http_status(:ok))
  end

  it "covers the neutral tone separately and says it is not drilled" do
    get("/tones")

    expect(response.body).to(include(I18n.t("tones.neutral_title")))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.neutral_taiwan"))))
  end

  it "spells out how Taiwan differs" do
    get("/tones")

    expect(response.body).to(include(I18n.t("tones.taiwan_title")))
    %w[third neutral merge].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.taiwan_points.#{key}"))))
    end
  end

  it "gives both sandhi rules, including 一 and 不" do
    get("/tones")

    expect(response.body).to(include(I18n.t("tones.third_title")))
    %w[yi_alone yi_before4 yi_other bu_before4 bu_other].each do |key|
      expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.yi_rules.#{key}"))))
    end
  end

  it "says tone production waits on speech recognition" do
    get("/tones")

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.practice_pending"))))
  end

  it "reads the tone off a zhuyin reading" do
    expect(Huayu::ToneDrill.tone_of("ㄇㄚ")).to(eq(1))
    expect(Huayu::ToneDrill.tone_of("ㄇㄚˊ")).to(eq(2))
    expect(Huayu::ToneDrill.tone_of("ㄇㄚˇ")).to(eq(3))
    expect(Huayu::ToneDrill.tone_of("ㄇㄚˋ")).to(eq(4))
  end

  it "leaves the neutral tone out of the drill entirely" do
    expect(Huayu::ToneDrill.tone_of("˙ㄉㄜ")).to(be_nil)
    expect(Huayu::ToneDrill.tone_of("")).to(be_nil)
  end

  it "carries the whole explainer in both locales" do
    %i[en ru].each do |locale|
      %w[why_body myth_body cannot_body cumulative_body third_body third_three neutral_body].each do |key|
        expect(I18n.t("tones.#{key}", locale:)).to(be_present)
      end
    end
  end

  it "marks the Taipei chart as the one to follow and the Beijing one as not" do
    get("/tones")

    expect(response.body).to(include("border-emerald-500/70"))
    expect(response.body).to(include("border-rose-500/45"))
    expect(response.body.index("border-emerald-500/70")).to(be < response.body.index("border-rose-500/45"))
  end

  it "never calls the Beijing pronunciation wrong in words" do
    %i[en ru].each do |locale|
      text = I18n.t("tones.chart.beijing_note", locale:)
      expect(text).not_to(match(/неверн|ошиб|wrong|incorrect|error/i))
    end
  end
end
