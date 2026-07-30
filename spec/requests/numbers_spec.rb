# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Numbers trainer" do
  it "opens on the characters stage" do
    get("/practice/numbers")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("numbers.stages.glyphs")))
  end

  it "serves every stage" do
    Huayu::NumberDrill::STAGES.each do |stage|
      get("/practice/numbers", params: {stage: stage})

      expect(response).to(have_http_status(:ok), stage)
    end
  end

  it "falls back to the first stage for an unknown one" do
    get("/practice/numbers", params: {stage: "nonsense"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("numbers.stage_hint.glyphs"))))
  end

  it "shows the four-digit grouping table rather than thousands" do
    get("/practice/numbers")

    expect(response.body).to(include("100 0000"))
    expect(response.body).to(include("一百萬"))
  end

  it "records a completed run against the practice counters" do
    post("/practice/numbers")

    expect(response).to(have_http_status(:no_content))
    expect(@authenticated_user.reload.practice_runs["numbers"]).to(eq(1))
  end

  it "spells out the trailing-digit rule that makes 三百五 mean 350" do
    get("/practice/numbers")

    expect(response.body).to(include(I18n.t("numbers.rules.truncation.title")))
    expect(response.body).to(include("三百五"))
    expect(response.body).to(include("三百零五"))
  end

  it "spells out when 兩 replaces 二" do
    get("/practice/numbers")

    expect(response.body).to(include(I18n.t("numbers.rules.liang.title")))
    expect(response.body).to(include("兩個人"))
    expect(response.body).to(include("二十"))
  end

  it "carries every rule in both locales" do
    %i[en ru].each do |locale|
      %w[truncation zero liang shi].each do |rule|
        expect(I18n.t("numbers.rules.#{rule}.body", locale:)).to(be_present)
        expect(I18n.t("numbers.rules.#{rule}.rows", locale:)).to(be_an(Array))
      end
    end
  end
end
