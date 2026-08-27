# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mood particles" do
  def particle(text, rank:, family: "mood", sole_sense: false, variants: nil, examples: nil)
    create(
      :lexeme,
      kind: :particle,
      text:,
      readings: {"pinyin" => "la", "zhuyin" => "˙ㄌㄚ"},
      meanings: {"en" => "summary of #{text}", "ru" => "суть #{text}"},
      data: {
        "rank" => rank,
        "family" => family,
        "corpus" => 100,
        "sole_sense" => sole_sense,
        "variants" => variants,
        "force" => {"en" => "force of #{text}", "ru" => "сила #{text}"},
        "body" => {"en" => ["body of #{text}"], "ru" => ["разбор #{text}"]},
        "examples" => examples
      }.compact
    )
  end

  it "lists the particles from the commonest down" do
    particle("喔", rank: 2)
    particle("啦", rank: 1)

    get("/zhuci")

    expect(response).to(have_http_status(:ok))
    expect(response.body.index("啦")).to(be < response.body.index("喔"))
  end

  it "filters by family" do
    particle("啦", rank: 1, family: "mood")
    particle("齁", rank: 2, family: "taiwan")

    get("/zhuci", params: {family: "taiwan"})

    expect(response.body).to(include("齁"))
    expect(response.body).not_to(include("summary of 啦"))
  end

  it "shows the detail page with its examples" do
    particle(
      "啦",
      rank: 1,
      examples: [
        {
          "zh" => "好啦好啦",
          "en" => "alright alright",
          "ru" => "ладно, ладно",
          "note_en" => "half exasperated",
          "note_ru" => "полудосада"
        }
      ]
    )

    get("/zhuci/#{CGI.escape("啦")}")

    expect(response.body).to(include("好啦好啦"))
    expect(response.body).to(include("half exasperated"))
    expect(response.body).to(include("body of 啦"))
  end

  it "reads the Russian side of an entry in the Russian interface" do
    particle(
      "啦",
      rank: 1,
      examples: [
        {
          "zh" => "好啦",
          "en" => "alright",
          "ru" => "ладно",
          "note_en" => "warm",
          "note_ru" => "по-доброму"
        }
      ]
    )

    in_locale(:ru) { get("/zhuci/#{CGI.escape("啦")}") }

    expect(response.body).to(include("полудосада").or(include("по-доброму")))
    expect(response.body).to(include("разбор 啦"))
  end

  it "sends a variant spelling to the particle that owns it" do
    particle(
      "啊",
      rank: 1,
      variants: [{"text" => "呀", "zhuyin" => "˙ㄧㄚ", "ru" => "после гласного"}]
    )

    get("/zhuci/#{CGI.escape("呀")}")

    expect(response).to(redirect_to(zhuci_entry_path("啊")))
  end

  it "answers a particle we have no article on with a not-found page" do
    get("/zhuci/#{CGI.escape("嘸")}")

    expect(response).to(have_http_status(:not_found))
  end

  it "sends the dictionary page to the particle when the word is nothing but the particle" do
    particle("齁", rank: 1, sole_sense: true)
    create(:lexeme, kind: :word, text: "齁", meanings: {"en" => "sentence-final particle"})

    get("/dict/#{CGI.escape("齁")}")

    expect(response).to(redirect_to(zhuci_entry_path("齁")))
  end

  it "keeps the dictionary page when the word carries more than the particle" do
    particle("吧", rank: 1)
    create(:lexeme, kind: :word, text: "吧", meanings: {"en" => "particle; bar, pub"}, readings: {"pinyin" => "ba"})

    get("/dict/#{CGI.escape("吧")}")

    expect(response).to(have_http_status(:ok))
  end

  it "offers the particle from the character page" do
    particle("喔", rank: 1)
    create(:lexeme, kind: :character, text: "喔", meanings: {"en" => "oh"}, readings: {"pinyin" => "ō"})

    get("/characters/#{CGI.escape("喔")}")

    expect(response.body).to(include(zhuci_entry_path("喔")))
  end
end
