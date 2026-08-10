# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ReadingForms do
  describe ".malformed?" do
    it "accepts one syllable per character" do
      expect(described_class).not_to(be_malformed("嘴唇", "ㄗㄨㄟˇ ㄔㄨㄣˊ"))
    end

    it "rejects a reading with a syllable missing" do
      expect(described_class).to(be_malformed("嘴唇", "ㄔㄨㄣˊ"))
    end

    it "rejects two readings run together" do
      expect(described_class).to(
        be_malformed("難兄難弟", "ㄋㄢˊ ㄒㄩㄥ ㄋㄢˊ ㄉㄧˋㄋㄢˋ ㄒㄩㄥ ㄋㄢˋ ㄉㄧˋ")
      )
    end

    it "accepts an 兒 ending that merges into the syllable before it" do
      expect(described_class).not_to(be_malformed("這兒", "ㄓㄜˋㄦ"))
      expect(described_class).not_to(be_malformed("模特兒", "ㄇㄛˊ ㄊㄜˋㄦ"))
    end

    it "says nothing about text that is not all Han" do
      expect(described_class).not_to(be_malformed("台灣Pay", "ㄊㄞˊ ㄨㄢ"))
    end

    it "says nothing when there is no reading to judge" do
      expect(described_class).not_to(be_malformed("嘴唇", ""))
      expect(described_class).not_to(be_malformed("嘴唇", nil))
    end
  end
end
