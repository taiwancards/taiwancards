# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::TextGate do
  subject(:gate) { described_class.instance }

  before { described_class.reset! }

  describe "tiers" do
    it "assigns everyday text to 常用" do
      expect(gate.call("我喜歡吃飯").tier).to(eq(Huayu::CharacterTiers::COMMON))
    end

    it "raises text to 次常用 on a single character" do
      secondary = Huayu::CharacterTiers.instance.chars_in(Huayu::CharacterTiers::SECONDARY).first
      expect(gate.call("我#{secondary}").tier).to(eq(Huayu::CharacterTiers::SECONDARY))
    end

    it "raises text to 罕用 on a single character" do
      rare = Huayu::CharacterTiers.instance.chars_in(Huayu::CharacterTiers::RARE).first
      expect(gate.call("我#{rare}").tier).to(eq(Huayu::CharacterTiers::RARE))
    end
  end

  describe "異體字 from the official lists" do
    %w[推薦 橋樑 白癡 那裏 床舖 勳章].each do |word|
      it "admits #{word} as 常用" do
        verdict = gate.call(word)
        expect(verdict).to(be_ok)
        expect(verdict.tier).to(eq(Huayu::CharacterTiers::COMMON))
      end
    end
  end

  describe "rejection" do
    it "cuts a character outside every chart" do
      verdict = gate.call("値得思考")
      expect(verdict.reason).to(eq(:unlisted))
      expect(verdict.offender).to(eq("値"))
    end

    it "cuts emoji and foreign symbols" do
      expect(gate.call("今天很好～").reason).to(eq(:junk))
      expect(gate.call("好棒😀").reason).to(eq(:junk))
      expect(gate.call("圍觀ｉｎｇ").reason).to(eq(:junk))
    end

    it "keeps Taiwanese punctuation" do
      expect(gate.call("他說：「你好嗎？」")).to(be_ok)
      expect(gate.call("等一下⋯⋯好")).to(be_ok)
      expect(gate.call("瑪莉‧史密斯是美國人")).to(be_ok)
    end

    it "requires at least one character" do
      expect(gate.call("LINE Pay").reason).to(eq(:no_han))
    end
  end

  describe "mainland markers" do
    it "cuts word-final erhua" do
      expect(gate.call("一點兒").reason).to(eq(:mainland))
      expect(gate.call("這件事有點兒難").reason).to(eq(:mainland))
    end

    it "leaves words where 兒 belongs to the root" do
      expect(gate.call("兒童遊戲場")).to(be_ok)
      expect(gate.call("我女兒很可愛")).to(be_ok)
      expect(gate.call("這是兒歌")).to(be_ok)
    end

    it "leaves Taiwanese colloquial forms with 兒" do
      expect(gate.call("那兒")).to(be_ok)
      expect(gate.call("人情味兒")).to(be_ok)
    end
  end
end
