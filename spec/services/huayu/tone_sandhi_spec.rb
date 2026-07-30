# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ToneSandhi do
  def surface(chars, tones)
    described_class.surface_tones(chars: chars.chars, base_tones: tones)
  end

  it "turns a run of third tones into second tones except the last" do
    expect(surface("你好", [3, 3])).to(eq([2, 3]))
    expect(surface("展覽館", [3, 3, 3])).to(eq([2, 2, 3]))
    expect(surface("很好", [3, 3])).to(eq([2, 3]))
  end

  it "leaves a lone third tone unchanged" do
    expect(surface("馬", [3])).to(eq([3]))
    expect(surface("好人", [3, 2])).to(eq([3, 2]))
  end

  it "reads 一 as tone 2 before a fourth tone and tone 4 otherwise" do
    expect(surface("一半", [1, 4])).to(eq([2, 4]))
    expect(surface("一天", [1, 1])).to(eq([4, 1]))
    expect(surface("一年", [1, 2])).to(eq([4, 2]))
    expect(surface("一起", [1, 3])).to(eq([4, 3]))
  end

  it "keeps 一 as tone 1 when it stands alone at the end" do
    expect(surface("一", [1])).to(eq([1]))
    expect(surface("第一", [4, 1])).to(eq([4, 1]))
  end

  it "reads 不 as tone 2 before a fourth tone and tone 4 otherwise" do
    expect(surface("不是", [4, 4])).to(eq([2, 4]))
    expect(surface("不對", [4, 4])).to(eq([2, 4]))
    expect(surface("不好", [4, 3])).to(eq([4, 3]))
    expect(surface("不能", [4, 2])).to(eq([4, 2]))
  end
end
