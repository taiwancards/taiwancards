# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Character readings" do
  let!(:jue) do
    create(
      :lexeme,
      :character,
      text: "覺",
      readings: {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"},
      meanings: {"ru" => "чувствовать"},
      data: {
        "readings" => [
          {"pinyin" => "jué", "zhuyin" => "ㄐㄩㄝˊ"},
          {"pinyin" => "jiào", "zhuyin" => "ㄐㄧㄠˋ"}
        ]
      }
    )
  end

  let!(:feel) { create(:lexeme, kind: :word, text: "覺得", meanings: {"ru" => "считать"}) }
  let!(:sleep) { create(:lexeme, kind: :word, text: "睡覺", meanings: {"ru" => "спать"}) }
  let!(:orphan) { create(:lexeme, kind: :word, text: "覺青", meanings: {"ru" => "молодёжь"}) }

  before do
    LexemeLink.create!(parent: feel, child: jue, position: 0, reading: "jué")
    LexemeLink.create!(parent: sleep, child: jue, position: 1, reading: "jiào")
    LexemeLink.create!(parent: orphan, child: jue, position: 0)
    jue.senses.create!(position: 0, reading: "jué", gloss_zh: "感受到。", meanings: {"en" => "to sense"})
    jue.senses.create!(position: 1, reading: "jiào", gloss_zh: "睡眠。", meanings: {"en" => "sleep"})
  end

  around do |example|
    dir = Pathname(Dir.mktmpdir)
    original = ENV["DATA_ROOT"]
    ENV["DATA_ROOT"] = dir.to_s

    chars = dir.join("moe_audio")
    chars.join("audio").mkpath
    chars.join("audio", "3485.opus").write("x")
    chars.join("index.json").write(
      {
        "version" => "20260626",
        "entries" => {
          "覺" => [{"id" => "3485", "zhuyin" => "ㄐㄩㄝˊ", "pinyin" => "jué", "head_ms" => 738}]
        }
      }.to_json
    )

    Huayu::MoeAudio.reset!
    example.run
    Huayu::MoeAudio.reset!
    ENV["DATA_ROOT"] = original
    dir.rmtree
  end

  def page
    get("/characters/#{CGI.escape("覺")}")
    expect(response).to(have_http_status(:ok))
    Nokogiri::HTML5(response.body)
  end

  it "shows every reading of the character with its own pinyin" do
    doc = page

    expect(doc.text).to(include("ㄐㄩㄝˊ").and(include("ㄐㄧㄠˋ")))
    expect(doc.text).to(include(I18n.t("characters.several_readings", count: 2)))
  end

  it "puts each word under the reading it is pronounced with" do
    container = page.css("section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("characters.readings") }
    groups = container.css("section")

    feeling = groups.find { |node| node.text.include?("ㄐㄩㄝˊ") }
    sleeping = groups.find { |node| node.text.include?("ㄐㄧㄠˋ") }

    expect(feeling.text).to(include("覺得").and(include("to sense")))
    expect(feeling.text).not_to(include("睡覺"))
    expect(sleeping.text).to(include("睡覺").and(include("sleep")))
    expect(sleeping.text).not_to(include("覺得"))
  end

  it "keeps the readings apart in the brief view too" do
    cookies["dict_detail"] = "brief"
    doc = page

    container = doc.css("section").find { |node| node.at_css("h2")&.text&.strip == I18n.t("characters.readings") }

    expect(container).to(be_present)
    expect(container.text).to(include("ㄐㄩㄝˊ").and(include("ㄐㄧㄠˋ")).and(include("睡覺")))
  end

  it "keeps a word of unknown reading out of the reading groups" do
    doc = page

    expect(doc.text).to(include(I18n.t("characters.reading_unknown")).and(include("覺青")))
  end

  it "never lends the recording of one reading to another, and leaves no reading silent" do
    urls = page.css("button[data-controller=audio]").map { |node| node["data-audio-url-value"] }.uniq

    expect(urls.size).to(eq(2))
    expect(urls.count { |url| url.include?("3485") }).to(eq(1))
    expect(urls.find { |url| !url.include?("3485") }).to(include("jiao4"))
  end

  describe "a word read two ways" do
    let!(:thing) do
      create(
        :lexeme,
        kind: :word,
        text: "東西",
        readings: {"pinyin" => "dōng xi", "zhuyin" => "ㄉㄨㄥ　˙ㄒㄧ"},
        meanings: {"en" => "thing"},
        data: {
          "readings" => [
            {"pinyin" => "dōng xi", "zhuyin" => "ㄉㄨㄥ　˙ㄒㄧ"},
            {"pinyin" => "dōng xī", "zhuyin" => "ㄉㄨㄥ　ㄒㄧ"}
          ]
        }
      )
    end

    before do
      thing.senses.create!(position: 0, reading: "dōng xi", gloss_zh: "物品。", meanings: {"en" => "a thing"})
      thing
        .senses
        .create!(position: 1, reading: "dōng xī", gloss_zh: "東方與西方。", meanings: {"en" => "east and west"})
    end

    it "marks each sense with the reading it belongs to" do
      get("/dict/#{CGI.escape("東西")}")
      expect(response).to(have_http_status(:ok))

      senses = Nokogiri::HTML5(response.body)
        .css("section")
        .find { |node| node.at_css("h2")&.text&.strip == I18n.t("words.senses") }
        .css("ol > li")
        .map { |node| node.text.gsub(/\s+/, " ").strip }

      expect(senses.first).to(include("˙ㄒㄧ").and(include("a thing")))
      expect(senses.last).to(include("ㄉㄨㄥ　ㄒㄧ").and(include("east and west")))
    end
  end
end
