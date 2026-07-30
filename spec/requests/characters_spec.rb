# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Characters" do
  let!(:zhang) do
    create(
      :lexeme,
      :character,
      text: "長",
      readings: {"pinyin" => "zhǎng", "zhuyin" => "ㄓㄤˇ"},
      meanings: {"en" => "long; to grow"},
      data: {
        "moe_index" => 42,
        "radical" => "長",
        "readings" => [
          {"pinyin" => "zhǎng", "zhuyin" => "ㄓㄤˇ"},
          {"pinyin" => "cháng", "zhuyin" => "ㄔㄤˊ"}
        ]
      }
    )
  end

  it "lists characters and filters by radical" do
    get("/characters")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("長"))

    get("/characters", params: {radical: "長"})
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("長"))
  end

  it "shows a character with its readings and linked words grouped by reading" do
    dianzhang = create(:lexeme, text: "店長", meanings: {"en" => "store manager"})
    yanchang = create(:lexeme, text: "延長", meanings: {"en" => "to extend"})
    LexemeLink.create!(parent: dianzhang, child: zhang, position: 1, reading: "zhǎng")
    LexemeLink.create!(parent: yanchang, child: zhang, position: 1, reading: "cháng")

    get("/characters/#{CGI.escape("長")}")
    expect(response).to(have_http_status(:ok))
    expect(response.body).to(include("ㄓㄤˇ", "ㄔㄤˊ", "店", "延"))
  end

  it "shows each linked word with its own reading, not just the character text" do
    dianzhang = create(
      :lexeme,
      text: "店長",
      readings: {"pinyin" => "diànzhǎng", "zhuyin" => "ㄉㄧㄢˋ ㄓㄤˇ"},
      meanings: {"en" => "store manager"}
    )
    LexemeLink.create!(parent: dianzhang, child: zhang, position: 1, reading: "zhǎng")

    get("/characters/#{CGI.escape("長")}")

    expect(response.body).to(include("ㄉㄧㄢˋ ㄓㄤˇ"))
    expect(response.body).to(include("store manager"))
  end

  it "orders a character's readings with the most-used one first" do
    create(:lexeme, text: "延長", data: {"freq_rank" => 400}).then do |w|
      LexemeLink.create!(parent: w, child: zhang, position: 1, reading: "cháng")
    end

    3.times do |index|
      create(:lexeme, text: "成長#{index}", data: {"freq_rank" => 10 + index}).then do |w|
        LexemeLink.create!(parent: w, child: zhang, position: 1, reading: "zhǎng")
      end
    end

    Huayu::ReadingRank.new.order(zhang.reload).then do |ordered|
      expect(ordered.first["zhuyin"]).to(eq("ㄓㄤˇ"))
    end
  end
end
