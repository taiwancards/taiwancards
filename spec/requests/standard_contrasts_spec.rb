# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Standard contrasts" do
  before { Huayu::StandardContrasts.reset! }

  after { Huayu::StandardContrasts.reset! }

  def contrast(section, key, side, locale = "en") = CGI.escapeHTML(
    Huayu::StandardContrasts.for(section, key, locale).fetch(side)
  )

  def page_text = Nokogiri::HTML(response.body).text.squish

  def plain(section, key, side, locale) = HanScript
    .plain(Huayu::StandardContrasts.for(section, key, locale).fetch(side))
    .squish

  def line(side) = response.body[%r{<p[^>]*data-standard="#{side}"[^>]*>}]

  it "sets Taipei and Beijing side by side under the initial they differ on" do
    read_in("en")
    get("/en/practice/zhuyin", params: {part: "initials"})

    expect(response.body).to(include("data-standard-legend"))
    expect(response.body).to(include("data-standard-contrast=\"initials\""))
    expect(response.body).to(include(contrast("initials", "zh", "taipei")))
    expect(response.body).to(include(contrast("initials", "zh", "beijing")))
    expect(response.body).to(include(contrast("blocks", "retroflex", "taipei")))
  end

  it "sets the Beijing line in smaller type than the Taipei one" do
    read_in("en")
    get("/en/practice/zhuyin", params: {part: "initials"})

    expect(line("beijing")).to(include("text-[11px]"))
    expect(line("taipei")).not_to(include("text-[11px]"))
    expect(line("taipei")).to(include("text-emerald-700"))
  end

  it "adds the contrast under the rimes too" do
    read_in("en")
    get("/en/practice/zhuyin", params: {part: "tricky"})

    expect(response.body).to(include(contrast("rimes", "er / erhua 兒", "beijing")))
  end

  it "keeps the legend off the part without tables" do
    read_in("en")
    get("/en/practice/zhuyin", params: {part: "intro"})

    expect(response.body).not_to(include("data-standard-legend"))
  end

  it "shows the legend, both charts, the contrasts and the words on the tones page" do
    read_in("en")
    get("/en/tones")

    expect(response.body).to(include("data-standard-legend"))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("standards.taipei_hint", locale: :en))))
    expect(response.body).to(include("border-emerald-500/70"))
    expect(response.body).to(include("data-tone-beijing"))
    expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.chart.beijing_note", locale: :en))))
    expect(response.body.scan("class=\"h-14 w-13\"").size).to(eq(4))
    expect(response.body).not_to(include("data-tone-reference"))

    expect(response.body).to(include(contrast("tones", "t3", "taipei")))
    expect(response.body).to(include(contrast("tones", "range", "beijing")))

    expect(response.body).to(include(CGI.escapeHTML(I18n.t("tones.words_title", locale: :en))))
    Huayu::StandardContrasts.words.each do |word|
      expect(response.body).to(include(dict_entry_path(word["text"], locale: "en")))
      expect(response.body).to(include(word.dig("taipei", "zhuyin")))
      expect(response.body).to(include(word["beijing"]))
    end
  end

  it "gives Vietnamese readers a neutral Hanoi chart beside the Beijing one" do
    read_in("vi")
    get("/vi/tones")

    reference = response.body[/<div[^>]*data-tone-reference="hanoi"[^>]*>/]
    expect(reference).to(be_present)
    expect(reference).not_to(include("rose"))
    expect(response.body).to(include("data-tone-beijing"))
    ToneChartHelper::CONTOURS["hanoi"].each_value do |chart|
      expect(response.body).to(include(chart[:label]))
    end
  end

  it "shows both standards in every language, on the initials and on the tones page" do
    Locales::ALL.each do |locale|
      read_in(locale)

      get("/#{locale}/practice/zhuyin", params: {part: "initials"})
      expect(response).to(have_http_status(:ok))
      %w[taipei beijing].each do |side|
        expect(page_text).to(include(plain("initials", "zh", side, locale)), "#{locale} zh #{side}")
      end

      get("/#{locale}/tones")
      expect(response).to(have_http_status(:ok))
      %w[taipei beijing].each do |side|
        expect(page_text).to(include(plain("tones", "t3", side, locale)), "#{locale} t3 #{side}")
      end
    end
  end
end
