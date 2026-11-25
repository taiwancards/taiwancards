# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tones" do
  def escaped(key) = CGI.escapeHTML(I18n.t(key))

  def between(from, to)
    start = response.body.index(from)
    response.body[start...response.body.index(to, start)]
  end

  def expect_contrast(html, key, sides: Huayu::StandardContrasts::SIDES)
    contrast = Huayu::StandardContrasts.for("tones", key)

    expect(contrast.keys).to(eq(sides))
    contrast.each do |side, text|
      expect(html).to(include("data-standard=\"#{side}\""))
      expect(html).to(include(CGI.escapeHTML(text)), "#{key} #{side}")
    end
  end

  it "explains why tones matter rather than only listing them" do
    get("/tones")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(escaped("tones.why_title")))
    expect(response.body).to(include(escaped("tones.myth_title")))
    expect(response.body).to(include(escaped("tones.cannot_title")))
  end

  it "opens with what a tone is before why it matters" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.what_title")))
    expect(response.body).to(include(escaped("tones.what_body")))
    expect(response.body.index(escaped("tones.what_title"))).to(be < response.body.index(escaped("tones.why_title")))
  end

  it "describes all four tones and charts them" do
    get("/tones")

    %w[t1 t2 t3 t4].each do |key|
      expect(response.body).to(include(escaped("tones.tones.#{key}.name")))
      expect(response.body).to(include(ToneChartHelper::CONTOURS["beijing"][key][:label]))
    end
  end

  it "puts Taipei before Beijing" do
    get("/tones")

    expect(response.body.index("border-emerald-500/70")).to(be < response.body.index("data-tone-beijing"))
    expect(response.body.index(escaped("tones.chart.taipei_note"))).to(
      be < response.body.index(escaped("tones.chart.beijing_note"))
    )
  end

  it "compares with the six Hanoi tones in a neutral chart for Vietnamese readers, Beijing kept small" do
    read_in("vi")
    get("/vi/tones")

    ToneChartHelper::CONTOURS["hanoi"].each_value do |contour|
      expect(response.body).to(include(contour[:label]))
    end

    hanoi = response.body.index("data-tone-reference=\"hanoi\"")
    beijing = response.body.index("data-tone-beijing")
    expect(hanoi).to(be < beijing)
    ToneChartHelper::CONTOURS["beijing"].each_value do |contour|
      expect(response.body.index(">#{contour[:label]}<")).to(be > beijing)
    end
  end

  it "gives figures for both charts and prints the measured Taipei ones inside the Taipei block" do
    expect(ToneChartHelper::CONTOURS["beijing"].values.map { |c| c[:label] }).to(all(be_present))
    expect(ToneChartHelper::CONTOURS["taipei"].values.map { |c| c[:label] }).to(eq(%w[44 323 312 42]))

    get("/tones")

    taipei = between("border-emerald-500/70", "data-tone-beijing")
    %w[44 323 312 42].each do |label|
      expect(taipei).to(include(">#{label}<"))
    end
  end

  it "lists every documented Taiwanese difference with both standards" do
    get("/tones")

    taiwan = between(escaped("tones.taiwan_title"), escaped("tones.segments_title"))
    %w[range merge erhua].each do |key|
      expect_contrast(taiwan, key)
    end

    expect(taiwan.scan("data-standard-contrast").size).to(eq(3))
  end

  it "covers the segmental differences as well as the tonal ones" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.segments_title")))
    %w[retroflex nasal].each do |key|
      expect(response.body).to(include(escaped("tones.segments.#{key}")))
      expect_contrast(response.body, key, sides: %w[beijing])
    end
  end

  it "draws the charts as inline svg, with no external image to license" do
    get("/tones")

    expect(response.body).to(include("<svg"))
    expect(response.body).not_to(match(/<img[^>]+wikimedia/i))
  end

  it "gives the practical hacks, including that the third tone is simply low" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.hacks_title")))
    %w[low pair start after_third fourth relative neutral].each do |key|
      expect(response.body).to(include(escaped("tones.hacks.#{key}")))
    end
  end

  it "keeps the drill on its own page so nothing plays unbidden" do
    get("/tones")
    expect(response.body).not_to(include("tone-drill"))
    expect(response.body).to(include(tones_drill_path))

    get("/tones/drill")
    expect(response).to(have_http_status(:ok))
  end

  it "covers the neutral tone separately and contrasts it in its own card" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.neutral_title")))
    expect_contrast(between(escaped("tones.neutral_title"), escaped("tones.taiwan_title")), "neutral")
  end

  it "spells out how Taiwan differs, tone by tone under each card" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.taiwan_title")))
    cards = between(escaped("tones.chart.scale"), escaped("tones.neutral_title"))
    %w[t1 t2 t3 t4].each do |key|
      expect_contrast(cards, key)
    end
  end

  it "gives both sandhi rules, including 一 and 不" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.third_title")))
    %w[yi_alone yi_before4 yi_other bu_before4 bu_other].each do |key|
      expect(response.body).to(include(escaped("tones.yi_rules.#{key}")))
    end
  end

  it "says tone production waits on speech recognition" do
    get("/tones")

    expect(response.body).to(include(escaped("tones.practice_pending")))
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
    expect(response.body).to(include("border-rose-500/40"))
    expect(response.body.index("border-emerald-500/70")).to(be < response.body.index("border-rose-500/40"))
    expect(response.body.scan("class=\"h-24 w-22\"").size).to(eq(4))
    expect(response.body.scan("class=\"h-14 w-13\"").size).to(eq(4))
  end

  it "never calls the reference pronunciation wrong in words" do
    %i[en ru vi].each do |locale|
      text = I18n.t("tones.chart.reference_note", locale:)
      expect(text).not_to(match(/неверн|ошиб|wrong|incorrect|error/i))
    end
  end
end
