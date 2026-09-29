# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::SimpToTrad do
  it "converts simplified characters found in community lyrics" do
    converted, changed = described_class.convert("再没有時間 小的时候 后来")

    expect(converted).to(eq("再沒有時間 小的時候 後來"))
    expect(changed).to(contain_exactly("没", "时", "后", "来"))
  end

  it "leaves Taiwan traditional text untouched" do
    converted, changed = described_class.convert("臺灣繁體字沒有問題")

    expect(converted).to(eq("臺灣繁體字沒有問題"))
    expect(changed).to(be_empty)
  end

  it "applies the Taiwan-specific override for ambiguous characters" do
    expect(described_class.convert("发").first).to(eq("發"))
    expect(described_class.convert("台湾").first).to(eq("臺灣"))
  end

  it "keeps characters that are also traditional when the text has nothing simplified" do
    expect(described_class.convert("上面見面，公里，皇后，若干，台北").first).to(
      eq("上面見面，公里，皇后，若干，台北")
    )
    expect(described_class.convert("上面见面").first).to(eq("上面見面"))
    expect(described_class.options("面")).to(eq(%w[面 麵]))
  end

  it "writes the forms Taiwan uses, not other traditional variants" do
    expect(described_class.convert("裏面爲了").first).to(eq("裡面為了"))
    expect(described_class.options("着")).to(eq(%w[著]))
    expect(described_class.options("里")).to(eq(%w[裡 里 哩]))
  end

  it "lists every traditional spelling a simplified character may stand for, the Taiwan default first" do
    expect(described_class.options("发")).to(eq(%w[發 髮]))
    expect(described_class.options("干")).to(include("乾", "幹"))
    expect(described_class.options("學")).to(eq(%w[學]))
  end

  it "handles blank input" do
    expect(described_class.convert(nil)).to(eq(["", []]))
  end
end
