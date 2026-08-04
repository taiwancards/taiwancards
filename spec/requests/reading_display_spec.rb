# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reading display" do
  let!(:lexeme) do
    create(
      :lexeme,
      kind: :character,
      text: "和",
      meanings: {"en" => "and", "ru" => "и"},
      readings: {"zhuyin" => "ㄏㄜˊ", "pinyin" => "hé"}
    )
  end

  it "shows the zhuyin and marks the pinyin as hideable" do
    get(character_path(text: "和"))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("ㄏㄜˊ"))
    expect(response.body).to(match(/class="pinyin[^"]*"[^>]*>\s*hé/m))
  end

  it "renders the zhuyin in a larger class than the pinyin" do
    get(character_path(text: "和"))

    expect(response.body).to(match(/text-2xl[^>]*lang="zh-TW"[^>]*>\s*ㄏㄜˊ/m))
  end

  it "hides pinyin when the browser cookie turns it off" do
    cookies[:show_pinyin] = "0"

    get(character_path(text: "和"))

    expect(response.body).to(match(/<html[^>]*class="[^"]*no-pinyin/))
  end

  it "hides pinyin until it is asked for" do
    get(character_path(text: "和"))

    expect(response.body).to(match(/<html[^>]*class="[^"]*no-pinyin/))
  end

  it "shows pinyin once the cookie asks for it" do
    cookies[:show_pinyin] = "1"
    get(character_path(text: "和"))

    expect(response.body).not_to(match(/<html[^>]*class="[^"]*no-pinyin/))
  end

  it "keeps the mainland word hidden until it is asked for" do
    get(character_path(text: "和"))
    expect(response.body).not_to(match(/<html[^>]*class="[^"]*show-mainland/))

    cookies[:show_mainland] = "1"
    get(character_path(text: "和"))
    expect(response.body).to(match(/<html[^>]*class="[^"]*show-mainland/))
  end

  it "uses the kai face by default and drops it when the cookie says sans" do
    get(character_path(text: "和"))
    expect(response.body).to(match(/<html[^>]*class="[^"]*font-kai/))

    cookies[:hanzi_font] = "sans"
    get(character_path(text: "和"))
    expect(response.body).not_to(match(/<html[^>]*class="[^"]*font-kai/))
  end

  it "annotates a word whose syllables are separated by a full-width space" do
    word = create(
      :lexeme,
      kind: :word,
      text: "我們",
      meanings: {"en" => "we"},
      readings: {"zhuyin" => "ㄨㄛˇ　˙ㄇㄣ", "pinyin" => "wǒmen"}
    )

    get(dict_entry_path(text: word.text))

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("<ruby"))
    expect(Nokogiri::HTML5(response.body).css("ruby.zy rt").map(&:text)).to(include("ㄨㄛˇ"))
  end
end
