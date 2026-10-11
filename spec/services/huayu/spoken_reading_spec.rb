# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SpokenReading do
  def lexeme(text, kind, pinyin, zhuyin, data: {})
    create(:lexeme, text:, kind:, readings: {"pinyin" => pinyin, "zhuyin" => zhuyin}, data:)
  end

  def spoken(text, standalone: true)
    described_class.pick(described_class.lexemes_for([text])[text], standalone:)&.dig("pinyin")
  end

  it "reads a particle standing alone in a sentence the way it is shown, with the neutral tone" do
    lexeme("著", :character, "zhuó", "ㄓㄨㄛˊ")
    lexeme("著", :word, "zhe", "˙ㄓㄜ")
    lexeme("地", :character, "dì", "ㄉㄧˋ")
    lexeme("地", :word, "de", "˙ㄉㄜ")

    expect([spoken("著"), spoken("地")]).to(eq(%w[zhe de]))
  end

  it "keeps the character's own reading when the word reading is a full tone" do
    lexeme("得", :character, "de", "˙ㄉㄜ")
    lexeme("得", :word, "dé", "ㄉㄜˊ")

    expect(spoken("得")).to(eq("de"))
  end

  it "reads 和 alone as hàn and left over inside an unknown phrase as hé" do
    readings = [{"pinyin" => "hàn", "zhuyin" => "ㄏㄢˋ"}, {"pinyin" => "hé", "zhuyin" => "ㄏㄜˊ"}]
    lexeme("和", :character, "hàn", "ㄏㄢˋ", data: {"readings" => readings})
    lexeme("和", :word, "hé", "ㄏㄜˊ")

    expect(spoken("和")).to(eq("hàn"))
    expect(spoken("和", standalone: false)).to(eq("hé"))
  end

  it "takes a longer text from its word or collocation entry" do
    lexeme("你好", :word, "nǐ hǎo", "ㄋㄧˇ ㄏㄠˇ")
    lexeme("國定假日", :collocation, "guó dìng jià rì", "ㄍㄨㄛˊ ㄉㄧㄥˋ ㄐㄧㄚˋ ㄖˋ")

    expect([spoken("你好"), spoken("國定假日"), spoken("謎語")]).to(
      eq(["nǐ hǎo", "guó dìng jià rì", nil])
    )
  end

  it "counts only common words, not names or set phrases, when splitting an unknown phrase" do
    lexeme("甜甜", :word, "Tiántián", "ㄊㄧㄢˊ ㄊㄧㄢˊ")
    lexeme("呱呱", :collocation, "gū gū", "ㄍㄨ ㄍㄨ")
    lexeme("溫和", :word, "wēnhé", "ㄨㄣ ㄏㄜˊ")
    found = described_class.lexemes_for(%w[甜甜 呱呱 溫和])

    expect(%w[甜甜 呱呱 溫和].map { |text| described_class.word?(found[text]) }).to(eq([false, false, true]))
  end

  it "splits an unknown phrase into the longest known words" do
    known = %w[氣候 溫和 溫].to_set

    expect(described_class.pieces("氣候溫和", known.method(:include?))).to(eq(%w[氣候 溫和]))
    expect(described_class.pieces("和局", known.method(:include?))).to(eq(%w[和 局]))
  end
end
