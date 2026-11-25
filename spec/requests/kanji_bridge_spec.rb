# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Kanji bridge for Japanese readers", :no_auth do
  let(:dir) { Pathname(Dir.mktmpdir("kanji-words")) }

  before do
    dir.join("words.json").write(
      JSON.generate(
        "勉強" => {
          "kind" => "shift",
          "jp" => "無理に、しぶしぶ",
          "note" => "日本語の勉強の意味ではありません"
        },
        "電話" => {"kind" => "same", "jp" => "電話"},
        "捷運" => {"kind" => "new", "jp" => "MRT"},
        "歷" => {"kind" => "new", "jp" => "経歴", "note" => "日本語では熟語の中だけ（歴史）"}
      )
    )
    stub_const("#{Huayu::KanjiBridge}::WORDS_PATH", dir.join("words.json"))
    Huayu::KanjiBridge.reset!
  end

  after { Huayu::KanjiBridge.reset! }

  def character!(text, zhuyin)
    create(:lexeme, :character, text:, readings: {"zhuyin" => zhuyin, "pinyin" => ""})
  end

  def word!(text, grade: 1)
    create(:lexeme, kind: :word, text:, readings: {"zhuyin" => "ㄅ", "pinyin" => "b"}, data: {"tbcl_grade" => grade})
  end

  describe "the guide" do
    it "opens in Japanese with the three sections" do
      %w[shapes readings meanings].each do |section|
        get("/ja/kanji", params: {section:})

        expect(response).to(have_http_status(:ok), section)
        expect(response.body).to(include(I18n.t("kanji_bridge.sections.#{section}", locale: :ja)))
      end
    end

    it "shows the measured patterns and the characters Japanese does not use" do
      get("/ja/kanji")

      expect(response.body).to(include("pattern-單"))
      expect(response.body).to(match(%r{<a[^>]*lang="zh-TW"[^>]*>們</a>}))
    end

    it "gives the measured share of the -n rule" do
      get("/ja/kanji", params: {section: "readings"})

      share = Huayu::KanjiBridge.readings.dig("nasals", "n", "reliability")
      expect(response.body).to(include(I18n.t("kanji_bridge.readings.nasal_n", locale: :ja)))
      expect(response.body).to(include("#{(share * 100).round(1).to_s.delete_suffix(".0")}%"))
    end

    it "lists the shifted words with their note, by level" do
      word!("勉強", grade: 2)

      get("/ja/kanji", params: {section: "meanings", level: 2})

      expect(response.body).to(
        include("勉強", "無理に、しぶしぶ", "日本語の勉強の意味ではありません")
      )
    end

    it "says the meaning list is coming while there is no word file" do
      stub_const("#{Huayu::KanjiBridge}::WORDS_PATH", dir.join("missing.json"))
      Huayu::KanjiBridge.reset!

      get("/ja/kanji", params: {section: "meanings"})

      expect(response.body).to(include(I18n.t("kanji_bridge.meanings.pending", locale: :ja)))
    end

    it "is not there in any other edition" do
      (Locales::ALL - %w[ja]).each do |code|
        get("/#{code}/kanji")

        expect(response).to(redirect_to("/#{code}/hanzi"), code)
      end
    end

    it "lets a shared cache hold the page" do
      get("/ja/kanji", params: {section: "readings"})

      expect(response.headers["Cache-Control"]).to(include("public", "s-maxage="))
      expect(response.headers["Set-Cookie"]).to(be_blank)
    end

    it "sits in the Japanese navigation only" do
      get("/ja/hanzi")
      expect(response.body).to(include("/ja/kanji"))

      get("/en/hanzi")
      expect(response.body).not_to(include("/kanji"))
    end
  end

  describe "the character page" do
    it "sets the Japanese form beside the Taiwan form and links the pattern" do
      character!("戰", "ㄓㄢˋ")

      get("/ja/characters/#{CGI.escape("戰")}")

      body = response.body
      expect(body).to(include(I18n.t("kanji_bridge.character.heading", locale: :ja), "lang=\"ja\"", "戦", "セン"))
      expect(body).to(include("#pattern-"))
    end

    it "says plainly when the form is the same" do
      character!("人", "ㄖㄣˊ")

      get("/ja/characters/#{CGI.escape("人")}")

      expect(response.body).to(include(I18n.t("kanji_bridge.character.same", locale: :ja), "ジン"))
    end

    it "marks a character Japanese does not use" do
      character!("們", "˙ㄇㄣ")

      get("/ja/characters/#{CGI.escape("們")}")

      expect(response.body).to(include(I18n.t("kanji_bridge.character.unused", locale: :ja)))
    end

    it "gives a one-character word its bridge tag and note" do
      character!("歷", "ㄌㄧˋ")

      get("/ja/characters/#{CGI.escape("歷")}")

      expect(response.body).to(
        include(I18n.t("kanji_bridge.meanings.kinds.new", locale: :ja), "日本語では熟語の中だけ（歴史）")
      )
    end

    it "leaves the other editions untouched" do
      character!("戰", "ㄓㄢˋ")

      get("/en/characters/#{CGI.escape("戰")}")

      expect(response.body).not_to(include("戦", "kanji"))
    end
  end

  describe "the word page" do
    it "tags a shifted word and gives its note" do
      word!("勉強")

      get("/ja/dict/#{CGI.escape("勉強")}")

      expect(response.body).to(
        include(
          I18n.t("kanji_bridge.meanings.kinds.shift", locale: :ja),
          "日本語の勉強の意味ではありません"
        )
      )
    end

    it "tags the other two kinds with a badge alone" do
      word!("電話")
      word!("捷運")

      get("/ja/dict/#{CGI.escape("電話")}")
      expect(response.body).to(include(I18n.t("kanji_bridge.meanings.kinds.same", locale: :ja)))

      get("/ja/dict/#{CGI.escape("捷運")}")
      expect(response.body).to(include(I18n.t("kanji_bridge.meanings.kinds.new", locale: :ja)))
    end

    it "gives the note of a new word as well when it has one" do
      word!("歷")

      get("/ja/dict/#{CGI.escape("歷")}")

      expect(response.body).to(
        include(
          I18n.t("kanji_bridge.meanings.kinds.new", locale: :ja),
          "経歴",
          "日本語では熟語の中だけ（歴史）"
        )
      )
    end

    it "shows no tag outside Japanese" do
      word!("勉強")

      get("/en/dict/#{CGI.escape("勉強")}")

      expect(response.body).not_to(include("日本語の勉強の意味ではありません"))
    end
  end

  describe "the level lists" do
    it "lets a Japanese reader keep only the words new to them" do
      word!("勉強")
      word!("捷運")

      get("/ja/tbcl/1", params: {bridge: "new"})

      expect(response.body).to(include("捷運"))
      expect(response.body).not_to(include(">勉強<"))
    end

    it "ignores the filter in other editions" do
      word!("勉強")
      word!("捷運")

      get("/en/tbcl/1", params: {bridge: "new"})

      expect(response.body).to(include("勉強", "捷運"))
      expect(response.body).not_to(include(I18n.t("kanji_bridge.filter.label", locale: :ja)))
    end
  end
end
