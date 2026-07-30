# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search" do
  def word(text, pinyin, zhuyin, score:, meaning: "meaning", kind: :word)
    create(
      :lexeme,
      kind:,
      text:,
      score:,
      readings: {"pinyin" => pinyin, "zhuyin" => zhuyin},
      meanings: {"en" => meaning},
      data: {"readings" => [{"pinyin" => pinyin, "zhuyin" => zhuyin}]}
    )
  end

  before { word("學校", "xuéxiào", "ㄒㄩㄝˊ ㄒㄧㄠˋ", score: 5, meaning: "school") }

  it "answers the quick panel with a fragment and no layout" do
    get("/search", params: {q: "xue2xiao4", frame: "1"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).not_to(include("<html"))
  end

  it "finds the word by every spelling of its reading" do
    %w[xuéxiào xue2xiao4 xuexiao ㄒㄩㄝˊㄒㄧㄠˋ ㄒㄩㄝㄒㄧㄠ 學校 school].each do |query|
      get("/search", params: {q: query, frame: "1"})

      expect(response.body).to(include("學校"), "expected #{query} to find 學校")
    end
  end

  it "offers a way through to the whole search" do
    get("/search", params: {q: "xuexiao", frame: "1"})

    expect(response.body).to(include(I18n.t("search.show_all")))
    expect(response.body).to(include("/search?pinyin=xuexiao"))
  end

  it "hands a reading to the field it was typed in and everything else to the text field" do
    get("/search", params: {q: "ㄒㄩㄝㄒㄧㄠ", frame: "1"})
    expect(response.body).to(include("zhuyin=%E3%84%92"))

    get("/search", params: {q: "school", frame: "1"})
    expect(response.body).to(include("/search?q=school"))
  end

  it "caps the panel at ten rows and says so" do
    15.times { |index| word("詞#{index}", "cí", "ㄘˊ", score: index + 1, meaning: "word #{index}") }

    get("/search", params: {q: "ci", frame: "1"})

    rows = Nokogiri::HTML5(response.body).css("[data-search-target='row']")
    expect(rows.size).to(eq(10))
    expect(response.body).to(include(I18n.t("search.showing_best", count: 10)))
  end

  it "shows pinyin when the reading was typed in pinyin and zhuyin otherwise" do
    get("/search", params: {q: "xuexiao", frame: "1"})
    expect(response.body).to(include("xuéxiào"))

    get("/search", params: {q: "ㄒㄩㄝㄒㄧㄠ", frame: "1"})
    expect(response.body).to(include("ㄒㄩㄝˊ ㄒㄧㄠˋ"))
  end

  it "renders the full page when asked without a frame" do
    get("/search", params: {q: "xuexiao"})

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("學校"))
    expect(response.body).to(include("<html"))
  end
end
