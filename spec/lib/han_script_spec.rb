# frozen_string_literal: true

require "rails_helper"

RSpec.describe HanScript do
  def mandarin(text, locale, context: nil)
    described_class.parse(text, locale, context:).pieces.select(&:last).map(&:first)
  end

  it "treats every Han run as Mandarin in an edition whose prose has no Han" do
    expect(mandarin("Use 了 after the verb: 我吃了。", :en)).to(eq(%w[了 我吃了]))
  end

  it "joins a Mandarin sentence across its own punctuation and keeps its final stop" do
    expect(mandarin("Reply 你好嗎？我很好。 then go", :en)).to(eq(["你好嗎？我很好。"]))
  end

  context("in the Japanese edition") do
    it "reads unmarked kanji as Japanese, even without kana around them" do
      expect(mandarin("台湾華語の発音と漢字、日本語の例文、案外、字形、型。", :ja)).to(eq([]))
      expect(mandarin("字形", :ja)).to(eq([]))
    end

    it "takes what the translator marked as Mandarin and drops the marks" do
      parsed = described_class.parse(
        "〘了〙は完了を表します。〘我是學生。〙 — 「私は学生です。」",
        :ja
      )

      expect(parsed.text).to(eq("了は完了を表します。我是學生。 — 「私は学生です。」"))
      expect(parsed.pieces.select(&:last).map(&:first)).to(eq(["了", "我是學生。"]))
    end

    it "knows a form Japanese never writes is Mandarin even when it is not marked" do
      expect(mandarin("學生と学生、黃と黄", :ja)).to(eq(%w[學生 黃]))
    end

    it "leaves a rare kanji Japanese prose really uses in the Japanese face" do
      expect(mandarin("篆書と倉頡入力、麻雀牌", :ja)).to(eq([]))
    end

    it "keeps Bopomofo with the Mandarin" do
      expect(mandarin("ㄅはバではありません", :ja)).to(eq(["ㄅ"]))
    end

    it "reads Han inside English fallback text as Mandarin" do
      expect(mandarin("Use 了 after the verb; 41巷 is a lane.", :ja)).to(eq(%w[了 巷]))
      expect(mandarin("了", :ja, context: "Use 了 after the verb")).to(eq(%w[了]))
      expect(mandarin(Locales.fallback("我(的)", :ja), :ja)).to(eq(%w[我 的]))
    end
  end

  it "strips the marks for plain text" do
    expect(described_class.plain("〘電話〙は日本語と同じ")).to(eq("電話は日本語と同じ"))
  end
end
