# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GlossText do
  it "keeps the traditional half of a CC-CEDICT pair" do
    expect(described_class.normalize("variant of 頹|颓[tui2]")).to(eq("variant of 頹"))
  end

  it "drops the numbered pinyin CC-CEDICT prints after a word" do
    expect(described_class.normalize("see 大名縣|大名县[Da4 ming2 Xian4]")).to(eq("see 大名縣"))
  end

  it "spells out the classifier list" do
    expect(described_class.normalize("blanket; quilt; CL:條|条[tiao2],床[chuang2]"))
      .to(eq("blanket; quilt; measure word: 條, 床"))
  end

  it "names measure words in Russian too" do
    expect(described_class.normalize("одеяло; CL:條|条[tiao2]", locale: "ru"))
      .to(eq("одеяло; счётное слово: 條"))
  end

  it "keeps a bracket that is not a reading" do
    expect(described_class.normalize("a counter (archaic)")).to(eq("a counter (archaic)"))
  end

  it "collapses a doublet written with a slash" do
    expect(described_class.normalize("short for 高等學校／高等学校 (gāoděng xuéxiào)"))
      .to(eq("short for 高等學校 (gāoděng xuéxiào)"))
  end

  it "is idempotent" do
    once = described_class.normalize("quilt; CL:條|条[tiao2],床[chuang2]")

    expect(described_class.normalize(once)).to(eq(once))
  end
end
