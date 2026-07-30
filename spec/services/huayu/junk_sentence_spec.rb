# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::JunkSentence do
  describe ".rejects?" do
    it "drops a single character chanted over and over" do
      expect(described_class.rejects?("國國國國國國國國國國")).to(be(true))
    end

    it "drops text built from two characters only" do
      expect(described_class.rejects?("說說話，說說話")).to(be(true))
    end

    it "drops text carrying a private use codepoint left by a broken glyph" do
      expect(described_class.rejects?("\u{E4D1}然部長都去拜訪了")).to(be(true))
    end

    it "drops a fragment that opens on a dangling conjunction" do
      expect(described_class.rejects?("與法界民間團體溝通", words: %w[與 法界 民間 團體 溝通])).to(
        be(true)
      )
    end

    it "drops a short fragment that trails off on a dangling preposition" do
      expect(described_class.rejects?("本文主旨為", words: %w[本文 主旨 為])).to(be(true))
    end

    it "keeps a long sentence that merely ends on 為 as a complete idiom" do
      words = %w[靠 自己 保護 自己 是 應該 的 若 國際 的 結構 有利 何樂而不為]
      expect(
        described_class.rejects?(
          "靠自己、保護自己是應該的，若國際的結構有利，何樂而不為",
          words:
        )
      )
        .to(be(false))
    end

    it "keeps an ordinary sentence" do
      expect(described_class.rejects?("我知道你在想什麼", words: %w[我 知道 你 在 想 什麼])).to(
        be(false)
      )
    end

    it "keeps a sentence when no segmentation is supplied" do
      expect(described_class.rejects?("與其他的議事組一樣")).to(be(false))
    end
  end
end

RSpec.describe Huayu::SentenceText do
  describe ".trim" do
    it "drops the orphan closing quote a corpus clip left behind" do
      expect(described_class.trim("」這是一個強制規定")).to(eq("這是一個強制規定"))
    end

    it "drops a leading comma and keeps the rest" do
      expect(described_class.trim("，我是他媽媽他在這裡嗎？")).to(eq("我是他媽媽他在這裡嗎？"))
    end

    it "keeps an opening quote that belongs to the sentence" do
      expect(described_class.trim("「我是台灣人")).to(eq("「我是台灣人"))
    end

    it "keeps an opening quote that follows an orphan mark" do
      expect(described_class.trim("」，「我是台灣人")).to(eq("「我是台灣人"))
    end

    it "leaves a clean sentence untouched" do
      expect(described_class.trim("我是台灣人")).to(eq("我是台灣人"))
    end
  end
end
