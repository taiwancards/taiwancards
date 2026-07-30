# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingQuery do
  def parse(query)
    described_class.call(query)
  end

  describe "the six ways of writing one reading" do
    it "folds every toned spelling of 你好 into the same pair of forms" do
      %w[nǐhǎo ni3hao3 ㄋㄧˇㄏㄠˇ].push("nǐ hǎo", "ni3 hao3", "ㄋㄧˇ ㄏㄠˇ").each do |query|
        result = parse(query)

        expect(result.pinyin_plain).to(eq("nihao"))
        expect(result.pinyin_toned).to(eq("ni3hao3"))
        expect(result.zhuyin_plain).to(eq("ㄋㄧㄏㄠ"))
        expect(result.zhuyin_toned).to(eq("ㄋㄧˇㄏㄠˇ"))
        expect(result).to(be_tones_given)
      end
    end

    it "folds every toneless spelling into the plain forms alone" do
      ["nihao", "ni hao", "ㄋㄧㄏㄠ", "ㄋㄧ ㄏㄠ"].each do |query|
        result = parse(query)

        expect(result.pinyin_plain).to(eq("nihao"))
        expect(result.zhuyin_plain).to(eq("ㄋㄧㄏㄠ"))
        expect(result.pinyin_toned).to(be_nil)
        expect(result.zhuyin_toned).to(be_nil)
        expect(result).not_to(be_tones_given)
      end
    end

    it "splits a run of syllables written without spaces" do
      expect(parse("xuexiao").pinyin_plain).to(eq("xuexiao"))
      expect(parse("xue2xiao4").pinyin_toned).to(eq("xue2xiao4"))
      expect(parse("xuéxiào").pinyin_toned).to(eq("xue2xiao4"))
    end
  end

  describe "tones" do
    it "reads a first tone written without a mark in zhuyin" do
      result = parse("ㄓㄨㄥˋㄧㄠˋ")

      expect(result).to(be_tones_given)
      expect(result.tones).to(eq([4, 4]))
    end

    it "treats an unmarked zhuyin syllable as first tone once any mark is present" do
      result = parse("ㄓㄨㄥㄧㄠˋ")

      expect(result).to(be_tones_given)
      expect(result.tones).to(eq([1, 4]))
    end

    it "reads the neutral tone written as a leading dot" do
      result = parse("˙ㄉㄜ")

      expect(result.pinyin_toned).to(eq("de5"))
      expect(result.zhuyin_toned).to(eq("˙ㄉㄜ"))
    end

    it "marks a query as partially toned when only some syllables carry a digit" do
      result = parse("ni3hao")

      expect(result).not_to(be_tones_given)
      expect(result).to(be_tones_partial)
      expect(result.tones).to(eq([3, nil]))
    end
  end

  describe "what is not a reading" do
    it "keeps hanzi out of the reading path" do
      result = parse("學校")

      expect(result).not_to(be_reading)
      expect(result).to(be_han)
      expect(result.han).to(eq("學校"))
    end

    it "gives up on latin that does not divide into syllables" do
      expect(parse("school")).not_to(be_reading)
      expect(parse("школа")).not_to(be_reading)
    end

    it "returns an empty result for an empty query" do
      expect(parse("   ")).not_to(be_reading)
    end
  end
end
