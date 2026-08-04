# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::SenseOrder do
  def build_hui
    lexeme = create(
      :lexeme,
      :character,
      text: "會",
      readings: {"pinyin" => "huì", "zhuyin" => "ㄏㄨㄟˋ"},
      data: {
        "readings" => [
          {"pinyin" => "huì", "zhuyin" => "ㄏㄨㄟˋ"},
          {"pinyin" => "kuài", "zhuyin" => "ㄎㄨㄞˋ"}
        ]
      }
    )
    lexeme.senses.create!(position: 0, reading: "kuài", meanings: {"en" => "accounting"})
    lexeme.senses.create!(position: 1, reading: "huì", meanings: {"en" => "to be able to"})
    lexeme
  end

  it "puts the senses of the main reading first" do
    lexeme = build_hui

    expect(described_class.new(io: StringIO.new).drift?).to(be(true))
    expect(described_class.new(io: StringIO.new).call.reordered).to(eq(1))

    expect(lexeme.senses.reload.map(&:reading)).to(eq(%w[huì kuài]))
  end

  it "settles after one pass" do
    build_hui
    described_class.new(io: StringIO.new).call

    expect(described_class.new(io: StringIO.new).drift?).to(be(false))
    expect(described_class.new(io: StringIO.new).call.reordered).to(eq(0))
  end

  it "leaves a character with a single reading exactly as the dictionary ordered it" do
    lexeme = create(:lexeme, :character, text: "水", readings: {"pinyin" => "shuǐ"})
    lexeme.senses.create!(position: 0, reading: nil, meanings: {"en" => "water"})
    lexeme.senses.create!(position: 1, reading: nil, meanings: {"en" => "a river"})

    described_class.new(io: StringIO.new).call

    expect(lexeme.senses.reload.map { |sense| sense.meaning(:en) }).to(eq(["water", "a river"]))
  end
end
