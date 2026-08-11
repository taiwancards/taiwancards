# frozen_string_literal: true

require "rails_helper"

RSpec.describe Graded::Readings do
  Line = Struct.new(:zh)
  Text = Struct.new(:lines)

  def readings_for(zh, tokens)
    analyzer = instance_double(Huayu::TextAnalyzer)
    allow(analyzer).to(receive(:segment).with(zh).and_return(tokens))
    described_class.new(analyzer: analyzer).lines(Text.new([Line.new(zh)]))[zh]
  end

  def entry(kind, text, zhuyin, pinyin)
    create(:lexeme, kind: kind, text: text, readings: {"zhuyin" => zhuyin, "pinyin" => pinyin})
  end

  it "splits the adverbial 都會 trap back into 都 and 會" do
    entry(:word, "都會", "ㄉㄨ ㄏㄨㄟˋ", "dū huì")
    entry(:word, "人人", "ㄖㄣˊ ㄖㄣˊ", "rén rén")
    entry(:character, "都", "ㄉㄡ", "dōu")
    entry(:character, "會", "ㄏㄨㄟˋ", "huì")
    entry(:character, "有", "ㄧㄡˇ", "yǒu")

    line = readings_for("人人都會有", %w[人人 都會 有])

    expect(line.pinyin).to(eq("rén rén dōu huì yǒu"))
    expect(line.zhuyin).to(eq("ㄖㄣˊ ㄖㄣˊ ㄉㄡ ㄏㄨㄟˋ ㄧㄡˇ"))
  end

  it "keeps 都會 whole in front of 區" do
    entry(:word, "都會", "ㄉㄨ ㄏㄨㄟˋ", "dū huì")
    entry(:character, "區", "ㄑㄩ", "qū")

    expect(readings_for("都會區", %w[都會 區]).pinyin).to(eq("dū huì qū"))
  end

  it "prefers the character reading for a standalone character" do
    entry(:word, "種", "ㄓㄨㄥˋ", "zhòng")
    entry(:character, "種", "ㄓㄨㄥˇ", "zhǒng")
    entry(:word, "這", "ㄓㄜˋ", "zhè / zhèi")
    entry(:character, "這", "ㄓㄜˋ", "zhè")

    expect(readings_for("這種", %w[這 種]).pinyin).to(eq("zhè zhǒng"))
  end

  it "lets a neutral-tone word reading beat the character citation" do
    entry(:word, "的", "˙ㄉㄜ", "de")
    entry(:character, "的", "ㄉㄧˋ", "dì")

    expect(readings_for("的", %w[的]).pinyin).to(eq("de"))
  end

  it "keeps only the first variant of a multi-reading entry" do
    entry(:word, "這", "ㄓㄜˋ", "zhè / zhèi")

    expect(readings_for("這", %w[這]).pinyin).to(eq("zhè"))
  end

  it "spells an unknown word character by character" do
    entry(:character, "夜", "ㄧㄝˋ", "yè")
    entry(:character, "市", "ㄕˋ", "shì")

    line = readings_for("夜市", %w[夜市])

    expect(line.pinyin).to(eq("yèshì"))
    expect(line.zhuyin).to(eq("ㄧㄝˋ ㄕˋ"))
  end
end
