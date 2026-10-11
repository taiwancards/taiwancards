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

  it "keeps 一 as tone 1 when it counts, orders or dates rather than quantifies" do
    expect(surface("第一次", [4, 1, 4])).to(eq([4, 1, 4]))
    expect(surface("十一點", [2, 1, 3])).to(eq([2, 1, 3]))
    expect(surface("一九九五", [1, 3, 3, 3])).to(eq([1, 2, 2, 3]))
    expect(surface("一百一十", [1, 3, 1, 2])).to(eq([4, 3, 1, 2]))
    expect(surface("一月一日", [1, 4, 1, 4])).to(eq([1, 4, 1, 4]))
    expect(surface("一個", [1, 4])).to(eq([2, 4]))
  end

  it "shifts 一 and 不 by the underlying tone when the next syllable is neutral" do
    expect(surface("一個", [1, 5])).to(eq([2, 5]))
    expect(surface("一下", [2, 5])).to(eq([2, 5]))
    expect(surface("一些", [4, 5])).to(eq([4, 5]))
    expect(surface("不了", [4, 5])).to(eq([4, 5]))
  end

  it "keeps 一 as tone 1 at the end of a longer word inside a sentence" do
    chars = "這是唯一的辦法".chars
    tones = [4, 4, 2, 1, 5, 4, 3]

    expect(described_class.surface_tones(chars:, base_tones: tones, word_ends: [1, 3, 6])[3]).to(eq(1))
    expect(described_class.surface_tones(chars:, base_tones: tones)[3]).to(eq(4))
  end

  it "stops every sandhi at a pause in the text" do
    expect(described_class.surface_tones(chars: %w[好 我], base_tones: [3, 3], phrase_starts: [1])).to(eq([3, 3]))
    expect(described_class.surface_tones(chars: %w[不 對], base_tones: [4, 4], phrase_starts: [1])).to(eq([4, 4]))
    expect(described_class.surface_tones(chars: %w[第 一 是], base_tones: [4, 1, 4], phrase_starts: [2])).to(
      eq([4, 1, 4])
    )
  end

  it "reads 不 as tone 2 before a fourth tone and tone 4 otherwise" do
    expect(surface("不是", [4, 4])).to(eq([2, 4]))
    expect(surface("不對", [4, 4])).to(eq([2, 4]))
    expect(surface("不好", [4, 3])).to(eq([4, 3]))
    expect(surface("不能", [4, 2])).to(eq([4, 2]))
  end
end
