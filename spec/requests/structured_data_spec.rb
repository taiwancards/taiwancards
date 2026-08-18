# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Structured data", :no_auth do
  it "describes a character so a search engine can read it as a dictionary entry" do
    create(
      :lexeme,
      kind: :character,
      text: "水",
      readings: {"zhuyin" => "ㄕㄨㄟˇ", "pinyin" => "shuǐ"},
      meanings: {"en" => "water"}
    )

    get("/characters/#{ERB::Util.url_encode("水")}")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("application/ld+json"))
    expect(response.body).to(include("DefinedTerm"))
    expect(response.body).to(include("zh-Hant-TW"))
  end

  it "describes a grammar point as a learning resource" do
    get("/grammar/gen-yiyang-same")

    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("LearningResource"))
  end
end
