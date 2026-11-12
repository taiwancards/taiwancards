# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictation::Grader do
  subject(:grader) { described_class.new("我也不知道") }

  def word(text, pinyin, zhuyin) = create(:lexeme, text:, readings: {"pinyin" => pinyin, "zhuyin" => zhuyin})

  def marks(answer) = grader.call(answer).cells.map(&:mark)

  before do
    word("我", "wǒ", "ㄨㄛˇ")
    word("也", "yě", "ㄧㄝˇ")
    word("不", "bù", "ㄅㄨˋ")
    word("知道", "zhīdào", "ㄓ ㄉㄠˋ")
    create(:lexeme, kind: :character, text: "到", readings: {"pinyin" => "dào", "zhuyin" => "ㄉㄠˋ"})
  end

  context("for a sentence read from its segments and its words") do
    before { create(:lexeme, :sentence, text: "我也不知道", segments: %w[我 也 不 知道]) }

    it "gives full marks to characters, toned pinyin and toned zhuyin alike" do
      ["我也不知道", "wo3 ye3 bu4 zhi1 dao4", "ㄨㄛˇ ㄧㄝˇ ㄅㄨˋ ㄓ ㄉㄠˋ"].each do |answer|
        expect(grader.call(answer).percent).to(eq(100), answer)
      end
    end

    it "shows each syllable in zhuyin assembled from the words" do
      expect(grader.targets.map(&:zhuyin)).to(eq(%w[ㄨㄛˇ ㄧㄝˇ ㄅㄨˋ ㄓ ㄉㄠˋ]))
    end

    it "accepts the tone heard in speech as well as the dictionary tone" do
      expect(marks("wo2 ye3 bu4 zhi1 dao4").first).to(eq(:exact))
    end

    it "takes a quarter off a syllable without a tone and half off a wrong tone" do
      expect(grader.call("wo ye bu zhi dao").percent).to(eq(75))
      expect(marks("wo4 ye3 bu4 zhi1 dao4").first).to(eq(:wrong_tone))
      expect(grader.call("wo4 ye3 bu4 zhi1 dao4").percent).to(eq(90))
    end

    it "gives half for another character with the same sound" do
      result = grader.call("我也不知到")

      expect(result.cells.last.mark).to(eq(:sound))
      expect(result.cells.last.typed).to(eq("到"))
      expect(result.percent).to(eq(90))
    end

    it "marks what was left out and counts extra syllables against the score" do
      expect(marks("我也")).to(eq([:exact, :exact, nil, nil, nil]))
      expect(grader.call("我也不知道我也").percent).to(eq(71))
      expect(grader.call("我也不知道我也").extra).to(eq(2))
    end

    it "scores an empty answer as nothing heard" do
      expect(grader.call("").percent).to(eq(0))
    end
  end

  it "takes a neutral syllable written without a tone as exact" do
    word("我們", "wǒmen", "ㄨㄛˇ ˙ㄇㄣ")
    word("走", "zǒu", "ㄗㄡˇ")
    word("吧", "ba", "˙ㄅㄚ")
    create(:lexeme, :sentence, text: "我們走吧", segments: %w[我們 走 吧])

    result = described_class.new("我們走吧").call("wo3 men zou3 ba")

    expect(result.cells.map(&:mark)).to(all(eq(:exact)))
    expect(result.percent).to(eq(100))
  end

  it "reads a text that no stored sentence holds from the words it is made of" do
    expect(grader.sentence).to(be_nil)
    expect(grader.call("wo3 ye3 bu4 zhi1 dao4").percent).to(eq(100))
  end

  it "prefers a reading stored on the sentence over the one its words give" do
    create(
      :lexeme,
      :sentence,
      text: "我也不知道",
      segments: %w[我 也 不 知道],
      readings: {"pinyin" => "wǒ yě bù zhīdao", "zhuyin" => "ㄨㄛˇ ㄧㄝˇ ㄅㄨˋ ㄓ ˙ㄉㄠ"}
    )

    expect(grader.targets.last.zhuyin).to(eq("˙ㄉㄠ"))
    expect(grader.call("wo3 ye3 bu4 zhi1 dao").percent).to(eq(100))
  end
end
