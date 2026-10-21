# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dictation::Answer do
  def read(text) = described_class.parse(text).map { |unit| [unit.char || unit.syllable, unit.tone] }

  it "keeps characters as they are typed" do
    expect(read("你好")).to(eq([["你", nil], ["好", nil]]))
  end

  it "reads pinyin with tone marks, tone numbers or no tones at all" do
    expect(read("zhīdào")).to(eq([["ㄓ", 1], ["ㄉㄠ", 4]]))
    expect(read("zhi1dao4")).to(eq([["ㄓ", 1], ["ㄉㄠ", 4]]))
    expect(read("zhidao")).to(eq([["ㄓ", nil], ["ㄉㄠ", nil]]))
  end

  it "splits run-together pinyin the way a reader would" do
    expect(read("fangan").map(&:first)).to(eq(%w[ㄈㄢ ㄍㄢ]))
    expect(read("xi'an").map(&:first)).to(eq(%w[ㄒㄧ ㄢ]))
    expect(read("lv3")).to(eq([["ㄌㄩ", 3]]))
  end

  it "reads zhuyin, where an unmarked syllable is the first tone once any tone is marked" do
    expect(read("ㄨㄛˇ ㄓㄉㄠˋ")).to(eq([["ㄨㄛ", 3], ["ㄓ", 1], ["ㄉㄠ", 4]]))
    expect(read("ㄨㄛ ㄓ")).to(eq([["ㄨㄛ", nil], ["ㄓ", nil]]))
  end

  it "takes the neutral mark both before a syllable and after it" do
    expect(read("ㄇㄚ ˙ㄇㄚ")).to(eq([["ㄇㄚ", 1], ["ㄇㄚ", 5]]))
    expect(read("ㄇㄚ ㄇㄚ˙")).to(eq([["ㄇㄚ", 1], ["ㄇㄚ", 5]]))
  end

  it "mixes scripts in one answer and keeps what cannot be read as a miss" do
    expect(read("我ye不")).to(eq([["我", nil], ["ㄧㄝ", nil], ["不", nil]]))
    expect(read("qwrtz")).to(eq([["?qwrtz", nil]]))
  end
end
