# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::ReadingOrder do
  let!(:zhi) do
    create(
      :lexeme,
      :character,
      text: "質",
      readings: {"pinyin" => "zhì", "zhuyin" => "ㄓˋ"},
      data: {"readings" => [{"pinyin" => "zhì", "zhuyin" => "ㄓˋ"}, {"pinyin" => "zhí", "zhuyin" => "ㄓˊ"}]}
    )
  end

  def word(text, reading, rank, level)
    lexeme = create(:lexeme, kind: :word, text:, data: {"freq_rank" => rank, "tocfl_level" => level})
    LexemeLink.create!(parent: lexeme, child: zhi, position: 1, reading:)
  end

  def run = described_class.new(io: StringIO.new).call

  it "rewrites both the headline reading and the stored list" do
    word("品質", "zhí", 300, "A2")
    word("本質", "zhí", 900, "B1")
    word("素質", "zhí", 2000, "B1")
    word("人質", "zhì", 8000, "C")

    expect(run.reordered).to(eq(1))

    zhi.reload
    expect(zhi.readings["zhuyin"]).to(eq("ㄓˊ"))
    expect(zhi.data["readings"].map { |reading| reading["zhuyin"] }).to(eq(%w[ㄓˊ ㄓˋ]))
  end

  it "reports drift only while an order is still wrong" do
    word("品質", "zhí", 300, "A2")
    word("本質", "zhí", 900, "B1")
    word("素質", "zhí", 2000, "B1")

    expect(described_class.new(io: StringIO.new).drift?).to(be(true))
    run
    expect(described_class.new(io: StringIO.new).drift?).to(be(false))
  end

  it "leads 和 with the reading Taiwan speaks most, hàn" do
    he = create(
      :lexeme,
      :character,
      text: "和",
      readings: {"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"},
      data: {"readings" => [{"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"}, {"pinyin" => "hàn", "zhuyin" => "ㄏㄢˋ"}]}
    )
    single = create(:lexeme, kind: :word, text: "和", data: {"freq_rank" => 10})
    LexemeLink.create!(parent: single, child: he, position: 1, reading: "hàn")
    peace = create(:lexeme, kind: :word, text: "和平", data: {"freq_rank" => 500, "tocfl_level" => "A2"})
    LexemeLink.create!(parent: peace, child: he, position: 1, reading: "hé")

    run

    he.reload
    expect(he.readings["pinyin"]).to(eq("hàn"))
    expect(he.data["readings"].map { |reading| reading["pinyin"] }).to(eq(%w[hàn hé]))
    expect(described_class.new(io: StringIO.new).drift?).to(be(false))
  end

  it "leaves a character alone when no graded vocabulary backs a change" do
    word("品質", "zhí", 300, nil)
    word("人質", "zhì", 8000, nil)

    expect(run.reordered).to(eq(0))
    expect(zhi.reload.readings["zhuyin"]).to(eq("ㄓˋ"))
  end
end
