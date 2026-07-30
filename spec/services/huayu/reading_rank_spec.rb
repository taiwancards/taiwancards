# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingRank do
  let!(:zhi) do
    create(
      :lexeme,
      :character,
      text: "質",
      readings: {"pinyin" => "zhì", "zhuyin" => "ㄓˋ"},
      data: {"readings" => [{"pinyin" => "zhì", "zhuyin" => "ㄓˋ"}, {"pinyin" => "zhí", "zhuyin" => "ㄓˊ"}]}
    )
  end

  def word(text, reading, rank)
    lexeme = create(:lexeme, kind: :word, text:, data: {"freq_rank" => rank})
    LexemeLink.create!(parent: lexeme, child: zhi, position: 1, reading:)
    lexeme
  end

  it "puts the reading that its common words use first" do
    word("品質", "zhí", 300)
    word("本質", "zhí", 900)
    word("人質", "zhì", 8000)

    ordered = described_class.new.order(zhi.reload)

    expect(ordered.map { |reading| reading["zhuyin"] }).to(eq(%w[ㄓˊ ㄓˋ]))
  end

  it "leaves a single-reading character untouched" do
    single = create(
      :lexeme,
      :character,
      text: "貓",
      readings: {"pinyin" => "māo", "zhuyin" => "ㄇㄠ"},
      data: {"readings" => [{"pinyin" => "māo", "zhuyin" => "ㄇㄠ"}]}
    )

    expect(described_class.new.order(single).map { |r| r["zhuyin"] }).to(eq(["ㄇㄠ"]))
  end

  it "keeps a reading that has no words below one that does, not above" do
    word("品質", "zhí", 300)

    ordered = described_class.new.order(zhi.reload)

    expect(ordered.first["zhuyin"]).to(eq("ㄓˊ"))
  end

  it "lifts a spoken function reading that has few compounds above the rare literary ones" do
    he = create(
      :lexeme,
      :character,
      text: "和",
      readings: {"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"},
      data: {
        "readings" => [
          {"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"},
          {"pinyin" => "hè", "zhuyin" => "ㄏㄜˋ"},
          {"pinyin" => "hàn", "zhuyin" => "ㄏㄢˋ"}
        ]
      }
    )
    create(:lexeme, kind: :word, text: "和平", data: {"freq_rank" => 200}).then do |w|
      LexemeLink.create!(parent: w, child: he, position: 0, reading: "hé")
    end

    create(:lexeme, kind: :word, text: "附和", data: {"freq_rank" => 6000}).then do |w|
      LexemeLink.create!(parent: w, child: he, position: 1, reading: "hè")
    end

    ordered = described_class.new.order(he.reload).map { |r| r["zhuyin"] }

    expect(ordered.first).to(eq("ㄏㄜˊ"))
    expect(ordered.index("ㄏㄢˋ")).to(be < ordered.index("ㄏㄜˋ"))
  end

  it "makes a spoken reading the main one when the dictionary and speech agree it dominates" do
    dou = create(
      :lexeme,
      :character,
      text: "都",
      readings: {"pinyin" => "dū", "zhuyin" => "ㄉㄨ"},
      data: {"readings" => [{"pinyin" => "dū", "zhuyin" => "ㄉㄨ"}, {"pinyin" => "dōu", "zhuyin" => "ㄉㄡ"}]}
    )
    create(:lexeme, kind: :word, text: "首都", data: {"freq_rank" => 500}).then do |w|
      LexemeLink.create!(parent: w, child: dou, position: 1, reading: "dū")
    end

    expect(described_class.new.order(dou.reload).first["zhuyin"]).to(eq("ㄉㄡ"))
  end
end
