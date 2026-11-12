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

  describe "a word written in the other spelling of 臺 and 台" do
    after { described_class.reset_vocabulary! }

    def link(text, word_text)
      described_class.new.analyze(text).find { |token| token.text == word_text }
    end

    it "links a 台 token to the 臺 entry when only that one exists" do
      taiwan = word!("臺北")
      allow(Huayu::SegmentationVocabulary).to(receive(:words).and_return(Set["台北"]))
      described_class.reset_vocabulary!

      expect(segment("我住在台北")).to(eq(%w[我 住 在 台北]))
      expect(link("我住在台北", "台北").lexeme).to(eq(taiwan))
    end

    it "links a 臺 token to the 台 entry when only that one exists" do
      stage = word!("舞台")
      allow(Huayu::SegmentationVocabulary).to(receive(:words).and_return(Set["舞臺"]))
      described_class.reset_vocabulary!

      expect(link("在舞臺上", "舞臺").lexeme).to(eq(stage))
    end

    it "prefers the spelling the text uses when both exist" do
      word!("臺啤")
      plain = word!("台啤")
      described_class.reset_vocabulary!

      expect(link("我們喝台啤", "台啤").lexeme).to(eq(plain))
    end

    it "looks the twins up in the same query as the words" do
      word!("臺北")
      allow(Huayu::SegmentationVocabulary).to(receive(:words).and_return(Set["台北"]))
      described_class.reset_vocabulary!
      analyzer = described_class.new
      analyzer.analyze("我住在台北")
      queries = []
      counter = -> (*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { analyzer.analyze("我住在台北") }

      expect(queries.size).to(eq(2))
    end
  end

  describe "a Taiwan word the vocabulary holds in one spelling only" do
    before { allow(Huayu::SegmentationVocabulary).to(receive(:words).and_return(Set.new)) }

    def analyzed(text, word_text)
      described_class.new.analyze(text).find { |token| token.text == word_text }
    end

    it "keeps 臺啤 whole and links it to the 台啤 entry" do
      beer = word!("台啤")
      described_class.reset_vocabulary!

      expect(segment("晚上喝臺啤")).to(include("臺啤"))
      expect(analyzed("晚上喝臺啤", "臺啤").lexeme).to(eq(beer))
    end

    it "keeps 台客 whole and links it to the 臺客 entry" do
      taike = word!("臺客")
      described_class.reset_vocabulary!

      expect(segment("他是台客")).to(include("台客"))
      expect(analyzed("他是台客", "台客").lexeme).to(eq(taike))
    end

    it "keeps a twin written with Latin letters whole" do
      word!("台北101")
      described_class.reset_vocabulary!

      expect(segment("我們去臺北101")).to(include("臺北101"))
    end

    it "gives a stage word no twin" do
      word!("舞台")
      word!("櫃台")
      described_class.reset_vocabulary!

      expect(described_class.vocabulary[:twins]).not_to(include("舞臺", "櫃臺"))
      expect(segment("在舞臺上")).not_to(include("舞臺"))
    end

    it "gives no twin to a spelling that cuts across a common word" do
      word!("台電")
      described_class.reset_vocabulary!

      expect(described_class.vocabulary[:twins]).not_to(include("臺電"))
    end

    it "does not glue a twin when a neighbouring token would form a word with it" do
      word!("臺客")
      word!("來臺")
      described_class.reset_vocabulary!

      expect(segment("請來台客")).not_to(include("來台"))
    end

    it "leaves a sentence without 臺 or 台 exactly as it was" do
      word!("台啤")
      described_class.reset_vocabulary!
      text = "我們可以在超級市場買東西"
      with_twins = segment(text)
      allow(described_class).to(
        receive(:vocabulary).and_wrap_original { |original| original.call.merge(twins: Set.new) }
      )

      expect(with_twins).to(eq(%w[我們 可以 在 超級 市場 買 東西]))
      expect(segment(text)).to(eq(with_twins))
    end

    it "rebuilds the twins with the rest of the vocabulary on reset" do
      word!("台啤")
      described_class.reset_vocabulary!
      expect(described_class.vocabulary[:twins]).to(include("臺啤"))

      word!("臺啤")
      expect(described_class.vocabulary[:twins]).to(include("臺啤"))

      described_class.reset_vocabulary!
      expect(described_class.vocabulary[:twins]).not_to(include("臺啤"))
      expect(described_class.vocabulary[:words]).to(include("臺啤"))
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

  describe "lunar-date normalization" do
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

    it "rebuilds 首都 when 都是 steals its tail" do
      word!("首都")
      word!("都是")
      described_class.reset_vocabulary!

      expect(segment("首都是姆巴巴內")).to(start_with("首都", "是"))
      expect(segment("希臘首都是雅典")).to(include("首都"))
    end

    it "leaves 首 alone after a tally" do
      word!("首都")
      word!("都是")
      described_class.reset_vocabulary!

      expect(segment("每首都是經典")).not_to(include("首都"))
      expect(segment("這兩首都是主題曲")).not_to(include("首都"))
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
