# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::Zhuyin do
  it "converts toned syllables" do
    expect(described_class.from_pinyin("nǐ")).to(eq("ㄋㄧˇ"))
    expect(described_class.from_pinyin("bù")).to(eq("ㄅㄨˋ"))
    expect(described_class.from_pinyin("huānyíng")).to(eq("ㄏㄨㄢ ㄧㄥˊ"))
  end

  it "marks neutral tone with a leading dot" do
    expect(described_class.from_pinyin("xièxie")).to(eq("ㄒㄧㄝˋ ˙ㄒㄧㄝ"))
  end

  it "handles the ü finals after j/q/x" do
    expect(described_class.from_pinyin("xuéxiào")).to(eq("ㄒㄩㄝˊ ㄒㄧㄠˋ"))
    expect(described_class.from_pinyin("qù")).to(eq("ㄑㄩˋ"))
  end

  it "keeps explicit ü" do
    expect(described_class.from_pinyin("lǜchá")).to(eq("ㄌㄩˋ ㄔㄚˊ"))
  end

  it "splits on spaces and apostrophes" do
    expect(described_class.from_pinyin("qiè'ér bùshě")).to(eq("ㄑㄧㄝˋ ㄦˊ ㄅㄨˋ ㄕㄜˇ"))
  end

  it "converts syllabic zhi/chi/shi/ri/zi/ci/si" do
    expect(described_class.from_pinyin("shì")).to(eq("ㄕˋ"))
    expect(described_class.from_pinyin("zhīdào")).to(eq("ㄓ ㄉㄠˋ"))
  end

  it "returns nil for non-pinyin input" do
    expect(described_class.from_pinyin("Chén Yuèměi!")).to(be_nil)
    expect(described_class.from_pinyin("")).to(be_nil)
    expect(described_class.from_pinyin(nil)).to(be_nil)
  end

  describe ".syllabify" do
    it "splits a word into per-character toned syllables with zhuyin" do
      expect(described_class.syllabify("chángdù")).to(
        eq(
          [
            {"pinyin" => "cháng", "zhuyin" => "ㄔㄤˊ"},
            {"pinyin" => "dù", "zhuyin" => "ㄉㄨˋ"}
          ]
        )
      )
    end

    it "handles spaced proper-name syllables" do
      expect(described_class.syllabify("Chén Yuèměi").map { |s| s["pinyin"] }).to(eq(%w[chén yuè měi]))
    end

    it "returns nil when it cannot segment" do
      expect(described_class.syllabify("xyz")).to(be_nil)
    end
  end

  it "backtracks when a greedy syllable match would strand the rest" do
    expect(described_class.from_pinyin("hánguó")).to(eq("ㄏㄢˊ ㄍㄨㄛˊ"))
    expect(described_class.from_pinyin("diànguō")).to(eq("ㄉㄧㄢˋ ㄍㄨㄛ"))
    expect(described_class.from_pinyin("yīnguǒ")).to(eq("ㄧㄣ ㄍㄨㄛˇ"))
    expect(described_class.from_pinyin("sānguó")).to(eq("ㄙㄢ ㄍㄨㄛˊ"))
  end

  it "still refuses input that is not pinyin at all" do
    expect(described_class.from_pinyin("qqq")).to(be_nil)
  end

  it "prefers the reading that does not strand a bare vowel syllable" do
    expect(described_class.from_pinyin("Méngtènèigēluó")).to(eq("ㄇㄥˊ ㄊㄜˋ ㄋㄟˋ ㄍㄜ ㄌㄨㄛˊ"))
    expect(described_class.from_pinyin("kǎoyā")).to(eq("ㄎㄠˇ ㄧㄚ"))
  end

  it "honors the apostrophe that pinyin uses to mark a vowel-initial syllable" do
    expect(described_class.from_pinyin("Qīlǐ'àn")).to(eq("ㄑㄧ ㄌㄧˇ ㄢˋ"))
    expect(described_class.from_pinyin("Dà'ān")).to(eq("ㄉㄚˋ ㄢ"))
    expect(described_class.from_pinyin("Shǒu'ěr")).to(eq("ㄕㄡˇ ㄦˇ"))
  end
end
