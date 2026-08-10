# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CharacterProfile do
  let!(:character) do
    Lexeme.create!(
      kind: :character,
      text: "不",
      readings: {"pinyin" => "bù", "zhuyin" => "ㄅㄨˋ"},
      data: {
        "readings" => [
          {"pinyin" => "bù", "zhuyin" => "ㄅㄨˋ"},
          {"pinyin" => "bú", "zhuyin" => "ㄅㄨˊ"}
        ]
      }
    )
  end

  def sense(reading, position)
    LexemeSense.create!(lexeme: character, reading:, position:, meanings: {"en" => "sense #{reading}"})
  end

  it "groups senses under the reading they belong to" do
    sense("bù", 0)
    sense("bú", 1)

    groups = described_class.new(character).reading_groups

    expect(groups.map { |group| group.reading["pinyin"] }).to(eq(%w[bù bú]))
    expect(groups.map { |group| group.senses.size }).to(eq([1, 1]))
  end

  it "keeps a sense whose reading the character no longer lists" do
    sense("bù", 0)
    literary = sense("fǒu", 1)

    groups = described_class.new(character).reading_groups
    extra = groups.find { |group| group.reading&.fetch("pinyin") == "fǒu" }

    expect(extra).not_to(be_nil)
    expect(extra.senses.map(&:id)).to(eq([literary.id]))
  end

  it "shows every sense of a character that has a single reading" do
    only = Lexeme.create!(
      kind: :character,
      text: "且",
      readings: {"pinyin" => "qiě", "zhuyin" => "ㄑㄧㄝˇ"},
      data: {"readings" => [{"pinyin" => "qiě", "zhuyin" => "ㄑㄧㄝˇ"}]}
    )
    LexemeSense.create!(lexeme: only, reading: "qiě", position: 0, meanings: {"en" => "moreover"})
    LexemeSense.create!(lexeme: only, reading: "jū", position: 1, meanings: {"en" => "literary particle"})

    groups = described_class.new(only).reading_groups

    expect(groups.sum { |group| group.senses.size }).to(eq(2))
  end
end
