# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Taiwanese loanword readings" do
  def import(entries)
    path = Rails.root.join("tmp/taigi_request_spec.json")
    path.write(entries.to_json)
    Huayu::TaiwanEverydayImporter.new(path:).call
  ensure
    path.delete if path.exist?
  end

  def entry(text, extra = {})
    {
      "text" => text,
      "pinyin" => "cè shì",
      "en" => "gloss #{text}",
      "ru" => "тест",
      "origin" => "hokkien",
      "register" => "casual",
      "domain" => "slang"
    }.merge(extra)
  end

  it "tells the reader that a native spelling is not read the Mandarin way" do
    import(
      [
        entry(
          "歹勢",
          "tailo" => "pháinn-sè",
          "taigi_reading" => "native",
          "say_zhuyin" => "ㄆㄞˋ ㄙㄝˋ",
          "say_pinyin" => "pài sè"
        )
      ]
    )

    in_locale(:ru) { get(dict_entry_path(text: "歹勢")) }

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("words.taigi_native", locale: :ru)))
    expect(response.body).to(include(I18n.t("words.taigi_say", locale: :ru)))
    expect(response.body).to(include("ㄆㄞˋ ㄙㄝˋ"))
    expect(response.body).to(include("pài sè"))
  end

  it "tells the reader that a sound spelling is read exactly as written" do
    import(
      [entry("賣安捏啦", "tailo" => "mài án-ne--lah", "hokkien" => "莫按呢啦", "taigi_reading" => "phonetic")]
    )

    in_locale(:ru) { get(dict_entry_path(text: "賣安捏啦")) }

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include(I18n.t("words.taigi_phonetic", locale: :ru)))
    expect(response.body).to(include("莫按呢啦"))
    expect(response.body).not_to(include(I18n.t("words.taigi_say", locale: :ru)))
  end

  it "says nothing about the reading when the entry does not classify itself" do
    import([entry("辦桌", "tailo" => "pān-toh")])

    get(dict_entry_path(text: "辦桌"))

    expect(response.body).to(include("pān-toh"))
    expect(response.body).not_to(include(I18n.t("words.taigi_native")))
    expect(response.body).not_to(include(I18n.t("words.taigi_phonetic")))
  end

  it "keeps an unknown classification out of the data" do
    import([entry("測試詞", "tailo" => "tshik-tshì", "taigi_reading" => "invented")])

    lexeme = Lexeme.find_by(kind: Lexeme.kinds[:word], text: "測試詞")

    expect(lexeme.data.dig("hokkien", "tailo")).to(eq("tshik-tshì"))
    expect(lexeme.data.dig("hokkien", "reading")).to(be_nil)
  end

  it "carries the four asked-for expressions in the shipped data" do
    shipped = JSON.parse(Rails.root.join("data/huayu/taiwan_everyday.json").read).index_by { |row| row["text"] }

    %w[賣安捏啦 甘安捏 那欸安捏 修但幾勒].each do |text|
      row = shipped.fetch(text)
      expect(row["origin"]).to(eq("hokkien"))
      expect(row["taigi_reading"]).to(eq("phonetic"))
      expect(row["tailo"]).to(be_present)
    end
  end
end
