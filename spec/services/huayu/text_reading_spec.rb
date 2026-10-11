# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TextReading do
  def keys(text, reading, words: nil) = described_class.rows(text, reading, words:).map { |row| row["key"] }

  it "expects the tones a word is actually spoken with, not the dictionary tones" do
    expect(keys("你好", "nǐ hǎo")).to(eq(%w[ni2 hao3]))
    expect(keys("不要", "bù yào")).to(eq(%w[bu2 yao4]))
    expect(keys("一點點", "yī diǎn diǎn")).to(eq(%w[yi4 dian2 dian3]))
  end

  it "keeps the dictionary tone beside the spoken one" do
    row = described_class.rows("你好", "nǐ hǎo").first

    expect(row.slice("tone", "base_tone")).to(eq("tone" => 2, "base_tone" => 3))
    expect(described_class.unshifted([row]).first.slice("tone", "key")).to(eq("tone" => 3, "key" => "ni3"))
  end

  it "lets a comma stop the third-tone sandhi across a pause" do
    expect(keys("好，我走", "hǎo wǒ zǒu")).to(eq(%w[hao3 wo2 zou3]))
    expect(keys("好我走", "hǎo wǒ zǒu")).to(eq(%w[hao2 wo2 zou3]))
  end

  it "reads 一 at the end of a sentence word with its own tone" do
    expect(keys("唯一的", "wéi yī de", words: %w[唯一 的])).to(eq(%w[wei2 yi1 de5]))
    expect(keys("有一本", "yǒu yī běn", words: %w[有 一 本])).to(eq(%w[you3 yi4 ben3]))
  end

  it "spells 都會 before a verb as dōu huì, the way the sentence is shown" do
    create(:lexeme, kind: :word, text: "都會", readings: {"pinyin" => "dū huì", "zhuyin" => "ㄉㄨ ㄏㄨㄟˋ"})
    create(:lexeme, kind: :word, text: "都", readings: {"pinyin" => "dōu", "zhuyin" => "ㄉㄡ"})
    create(:lexeme, kind: :word, text: "會", readings: {"pinyin" => "huì", "zhuyin" => "ㄏㄨㄟˋ"})
    create(:lexeme, kind: :word, text: "區", readings: {"pinyin" => "qū", "zhuyin" => "ㄑㄩ"})
    create(:lexeme, kind: :word, text: "來", readings: {"pinyin" => "lái", "zhuyin" => "ㄌㄞˊ"})

    expect(described_class.new.spell(%w[都會 來])).to(eq("dōu huì lái"))
    expect(described_class.new.spell(%w[都會 區])).to(eq("dū huì qū"))
  end

  it "ignores word boundaries that do not cover the text" do
    expect(keys("唯一的", "wéi yī de", words: %w[唯一])).to(eq(%w[wei2 yi4 de5]))
  end
end
