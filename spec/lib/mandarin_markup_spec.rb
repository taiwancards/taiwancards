# frozen_string_literal: true

require "rails_helper"

RSpec.describe MandarinMarkup do
  def page(body, lang: "ja") = "<!DOCTYPE html><html lang=\"#{lang}\" class=\"font-kai\"><head><title>骨</title></head><body>#{body}</body></html>"

  it "marks the Mandarin the translator marked, leaves Japanese words Japanese and keeps the page attributes" do
    html = described_class.call(
      page("<p>〘骨〙は日本語の骨と形が違います。例文、字形、案外。</p>"),
      locale: :ja
    )
    paragraph = Nokogiri::HTML5(html).at_css("p")

    expect(html).to(include("<html lang=\"ja\" class=\"font-kai\">"))
    expect(paragraph.css("[lang='zh-TW']").map(&:text)).to(eq(%w[骨]))
    expect(paragraph.text).to(eq("骨は日本語の骨と形が違います。例文、字形、案外。"))
  end

  it "reads the language of a whole block, so a word in its own element inside English fallback stays Mandarin" do
    html = described_class.call(page("<p>Use <b>了</b> after the verb.</p>"), locale: :ja)

    expect(Nokogiri::HTML5(html).css("b [lang='zh-TW']").map(&:text)).to(eq(%w[了]))
  end

  it "leaves text that already says its language, the title and scripts alone, and drops marks from attributes" do
    body = "<span lang=\"zh-TW\">說話</span><span lang=\"en\">日本語</span><a title=\"〘說〙の意味\">x</a><script>var a = \"說\";</script>"
    document = Nokogiri::HTML5(described_class.call(page(body), locale: :ja))

    expect(document.css("[lang='zh-TW']").size).to(eq(1))
    expect(document.at_css("a")["title"]).to(eq("說の意味"))
    expect(document.at_css("title").text).to(eq("骨"))
    expect(document.at_css("script").text).to(include("\"說\""))
  end

  it "keeps a fragment a fragment" do
    html = described_class.call("<li class=\"hit\">〘黃〙 — 黄色</li>", locale: :ja)

    expect(html).to(eq("<li class=\"hit\"><span lang=\"zh-TW\">黃</span> — 黄色</li>"))
  end

  it "returns text without Han untouched" do
    expect(described_class.call(page("<p>Hello</p>"), locale: :ja)).to(eq(page("<p>Hello</p>")))
  end
end
