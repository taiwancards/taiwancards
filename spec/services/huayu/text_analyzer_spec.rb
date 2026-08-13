# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TextAnalyzer do
  def word!(text)
    Lexeme.find_or_create_by!(kind: :word, text:)
  end

  def char!(text)
    Lexeme.find_or_create_by!(kind: :character, text:)
  end

  def segment(text)
    described_class.new.analyze(text).reject { |t| t.kind == :literal }.map(&:text)
  end

  before do
    %w[
      不容
      容易
      新手
      手機
      是非
      非常
      在職
      職場
      不及
      及格
      大地
      地震
      這個
      什麼
      只是
      再見
      見到
      下雨
      下雪
      不下
      就算
      算了
      一下
      人員
      員工
      工商
      高級
      管理
      碩士
      超級
      市場
      東西
      方便
      我們
      可以
      生活
      工作
    ]
      .each { |w| word!(w) }
    "不容易新手機是非常在職場及格大地震這個什麼只是再見到下雨雪就算了一人員工商高級管理碩士超市場東西方便我們可以生活"
      .each_char { |c| char!(c) }
  end

  describe "ambiguity the greedy passes got wrong" do
    {
      "不容易" => %w[不 容易],
      "新手機" => %w[新 手機],
      "那是非常" => %w[那 是 非常],
      "在職場" => %w[在 職場],
      "不及格" => %w[不 及格],
      "大地震" => %w[大 地震],
      "再見到" => %w[再 見到],
      "不下雪" => %w[不 下雪]
    }.each do |input, expected|
      it "splits #{input} as #{expected.join(" / ")}" do
        expect(segment(input)).to(eq(expected))
      end
    end
  end

  describe "words the frequency model must not break apart" do
    %w[這個 什麼 只是 方便 我們 可以].each do |word|
      it "keeps #{word} whole" do
        expect(segment(word)).to(eq([word]))
      end
    end
  end

  describe "ordinary sentences" do
    it "segments a everyday sentence" do
      expect(segment("我們可以在超級市場買東西")).to(
        eq(%w[我們 可以 在 超級 市場 買 東西])
      )
    end

    it "leaves punctuation and latin outside the han runs" do
      tokens = described_class.new.analyze("我們可以，OK？")
      expect(tokens.select { |t| t.kind == :literal }.map(&:text)).to(include("，OK？"))
    end

    it "returns nothing for blank input" do
      expect(described_class.new.analyze("   ")).to(eq([]))
    end
  end

  describe "characters with no dictionary entry" do
    it "keeps an unknown character as its own token rather than dropping it" do
      expect(segment("我們鑫可以")).to(eq(%w[我們 鑫 可以]))
    end
  end

  describe "mixed-script vocabulary words" do
    it "keeps a Latin-plus-Han word whole" do
      word!("K書")
      word!("中心")
      described_class.reset_vocabulary!

      expect(segment("我在K書中心")).to(eq(%w[我 在 K書 中心]))
    end

    it "keeps a zhuyin-written word whole" do
      word!("ㄍㄧㄥ")
      described_class.reset_vocabulary!

      tokens = described_class.new.analyze("不要再ㄍㄧㄥ了")
      expect(tokens.map(&:text)).to(include("ㄍㄧㄥ"))
    end

    it "refuses the match when the Latin part continues" do
      word!("K書")
      described_class.reset_vocabulary!

      tokens = described_class.new.analyze("OK書店")
      expect(tokens.map(&:text)).not_to(include("K書"))
    end
  end

  describe "lunar-date normalisation" do
    it "rebuilds month and day around a stolen 月初" do
      word!("月初")
      word!("七月")
      word!("初一")
      described_class.reset_vocabulary!

      expect(segment("七月初一")).to(eq(%w[七月 初一]))
    end

    it "leaves a real 月初 alone" do
      word!("月初")
      described_class.reset_vocabulary!

      expect(segment("七月初的天氣")).to(include("月初"))
    end

    it "keeps 媽祖 ahead of 祖廟" do
      word!("媽祖")
      word!("祖廟")
      described_class.reset_vocabulary!

      expect(segment("媽祖廟")).to(eq(%w[媽祖 廟]))
    end

    it "keeps the good brothers whole before 們" do
      word!("好兄弟")
      word!("兄弟")
      described_class.reset_vocabulary!

      expect(segment("好兄弟們")).to(eq(%w[好兄弟 們]))
    end
  end

  describe "the merge pass" do
    it "does not re-glue a span the frequency model already rejected" do
      word!("我等")
      described_class.reset_vocabulary!

      expect(described_class.vocabulary[:words]).to(include("我等"))
      expect(segment("我等一下")).to(eq(%w[我 等 一下]))
    end

    it "still merges a span the frequency model never saw" do
      Lexeme.find_or_create_by!(kind: :measure_word, text: "公斤")
      described_class.reset_vocabulary!

      expect(described_class.vocabulary[:words]).not_to(include("公斤"))
      expect(segment("公斤")).to(eq(["公斤"]))
    end
  end
end
