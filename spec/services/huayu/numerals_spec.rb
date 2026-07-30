# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::Numerals do
  def spell(...) = described_class.spell(...)

  it "spells the single digits" do
    expect((0..9).map { |n| spell(n) }).to(eq(%w[零 一 二 三 四 五 六 七 八 九]))
  end

  it "drops the leading 一 in the teens but keeps it above a hundred" do
    expect(spell(10)).to(eq("十"))
    expect(spell(15)).to(eq("十五"))
    expect(spell(19)).to(eq("十九"))
    expect(spell(110)).to(eq("一百一十"))
    expect(spell(115)).to(eq("一百一十五"))
  end

  it "uses 兩 for the hundreds, thousands and myriads but 二 for the tens" do
    expect(spell(2)).to(eq("二"))
    expect(spell(20)).to(eq("二十"))
    expect(spell(22)).to(eq("二十二"))
    expect(spell(200)).to(eq("兩百"))
    expect(spell(2000)).to(eq("兩千"))
    expect(spell(20_000)).to(eq("兩萬"))
    expect(spell(222)).to(eq("兩百二十二"))
  end

  it "can be asked for the 二 forms instead" do
    expect(spell(200, liang: false)).to(eq("二百"))
    expect(spell(2000, liang: false)).to(eq("二千"))
  end

  it "inserts a single 零 for an internal gap" do
    expect(spell(105)).to(eq("一百零五"))
    expect(spell(1005)).to(eq("一千零五"))
    expect(spell(1050)).to(eq("一千零五十"))
    expect(spell(10_005)).to(eq("一萬零五"))
  end

  it "never puts a 零 where the gap is only trailing" do
    expect(spell(100)).to(eq("一百"))
    expect(spell(1000)).to(eq("一千"))
    expect(spell(1500)).to(eq("一千五百"))
    expect(spell(15_000)).to(eq("一萬五千"))
  end

  it "groups by ten thousand rather than by thousand" do
    expect(spell(10_000)).to(eq("一萬"))
    expect(spell(100_000)).to(eq("十萬"))
    expect(spell(1_000_000)).to(eq("一百萬"))
    expect(spell(10_000_000)).to(eq("一千萬"))
    expect(spell(100_000_000)).to(eq("一億"))
    expect(spell(1_000_000_000)).to(eq("十億"))
  end

  it "handles a skipped group with one 零" do
    expect(spell(100_000_005)).to(eq("一億零五"))
    expect(spell(100_050_000)).to(eq("一億零五萬"))
    expect(spell(100_005_000)).to(eq("一億零五千"))
  end

  it "spells a realistic Taiwanese price and population" do
    expect(spell(23_500_000)).to(eq("兩千三百五十萬"))
    expect(spell(1_250)).to(eq("一千兩百五十"))
  end

  it "spells the formal financial forms without 兩" do
    expect(spell(2, formal: true)).to(eq("貳"))
    expect(spell(200, formal: true)).to(eq("貳佰"))
    expect(spell(10, formal: true)).to(eq("壹拾"))
    expect(spell(105, formal: true)).to(eq("壹佰零伍"))
  end

  it "splits into four-digit groups from the right" do
    expect(described_class.split_groups(123_456_789)).to(eq([6789, 2345, 1]))
  end

  it "refuses a negative number and anything past the supported range" do
    expect { spell(-1) }.to(raise_error(ArgumentError))
    expect { spell(described_class::MAX + 1) }.to(raise_error(ArgumentError))
  end
end
