# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Metro map" do
  let(:path) { Rails.root.join("tmp/metro_spec.json") }

  before do
    path.write(
      [
        {
          "text" => "台北車站",
          "pinyin" => "Táiběi Chēzhàn",
          "en" => "Taipei Main Station",
          "origin" => "taiwan-mandarin",
          "register" => "neutral",
          "domain" => "transport",
          "lines" => {"淡水信義線" => 8, "板南線" => 11},
          "lat" => 25.046,
          "lon" => 121.517
        },
        {
          "text" => "西門",
          "pinyin" => "Xīmén",
          "en" => "Ximen",
          "origin" => "taiwan-mandarin",
          "register" => "neutral",
          "domain" => "transport",
          "lines" => {"板南線" => 10},
          "lat" => 25.042,
          "lon" => 121.508
        },
        {
          "text" => "珍奶",
          "pinyin" => "zhēnnǎi",
          "en" => "bubble tea",
          "origin" => "abbreviation",
          "register" => "casual",
          "domain" => "food"
        }
      ].to_json
    )
    Huayu::TaiwanEverydayImporter.new(path:).call
  end

  after { path.delete if path.exist? }

  it "draws every line that has stations" do
    sign_in(create(:user))

    get(metro_path)

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("台北車站", "西門", "板南線", "淡水信義線"))
  end

  it "keeps non-station vocabulary off the map" do
    sign_in(create(:user))

    get(metro_path)

    node = Nokogiri::HTML(response.body).at("[data-metro-map-cards-value]")
    expect(JSON.parse(node["data-metro-map-cards-value"]).keys).not_to(include("珍奶"))
    expect(response.body).not_to(include("data-station=\"珍奶\""))
  end

  it "ships the card data every station needs, interchanges included" do
    sign_in(create(:user))

    get(metro_path)

    node = Nokogiri::HTML(response.body).at("[data-metro-map-cards-value]")
    cards = JSON.parse(node["data-metro-map-cards-value"])

    expect(cards.keys).to(contain_exactly("台北車站", "西門"))
    expect(cards["台北車站"]).to(include("zhuyin" => "ㄊㄞˊ ㄅㄟˇ ㄔㄜ ㄓㄢˋ"))
    expect(cards["台北車站"]["lines"]).to(eq(["淡水信義線", "板南線"]))
    expect(cards["西門"]["href"]).to(eq(dict_entry_path("西門")))
  end

  it "puts an interchange on both of its lines" do
    sign_in(create(:user))

    get(metro_path)

    expect(response.body.scan("台北車站").size).to(be >= 2)
  end
end
