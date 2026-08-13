# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::EtymologyText do
  it "keeps only the traditional half of a doublet written with a fullwidth slash" do
    expect(described_class.normalize("Short for 臺灣獨立運動／台湾独立运动 (Táiwān dúlì yùndòng)."))
      .to(eq("Short for 臺灣獨立運動 (Táiwān dúlì yùndòng)."))
  end

  it "keeps only the traditional half of a doublet written with an ascii slash" do
    expect(described_class.normalize("Phono-semantic compound (形聲 /形声, OC *hljɯɡs)"))
      .to(eq("Phono-semantic compound (形聲, OC *hljɯɡs)"))
  end

  it "collapses a doublet of quoted titles" do
    expect(described_class.normalize("From 《世說新語·言語》 /《世说新语·言语》"))
      .to(eq("From 《世說新語·言語》"))
  end

  it "leaves a slash between unrelated words alone" do
    expect(described_class.normalize("Compare 凸/凹 in the modern form."))
      .to(eq("Compare 凸/凹 in the modern form."))
  end

  it "converts a simplified quotation into traditional" do
    expect(described_class.normalize("From I Ching, Hexagram 25 (《易经·无妄》)"))
      .to(eq("From I Ching, Hexagram 25 (《易經·無妄》)"))
  end

  it "leaves a single character quoted as a glyph alone" do
    expect(described_class.normalize("Originally written as 从. Semantic 广 (“house”)."))
      .to(eq("Originally written as 从. Semantic 广 (“house”)."))
  end

  it "leaves a character whose traditional reading depends on the sense alone" do
    expect(described_class.normalize("Contrast 后 and 面 in Taiwan."))
      .to(eq("Contrast 后 and 面 in Taiwan."))
  end

  it "drops a clause repeated in simplified right after the traditional one" do
    expect(described_class.normalize("Short for 仁者見仁，智者見智，智者见智 (rénzhě jiàn rén)."))
      .to(eq("Short for 仁者見仁，智者見智 (rénzhě jiàn rén)."))
  end

  it "keeps a word that legitimately reappears later in an enumeration" do
    text = "Japanese 起點: 國腦、國粹、起點、內容"

    expect(described_class.normalize(text)).to(eq(text))
  end

  it "names China rather than the mainland" do
    expect(described_class.normalize("This has been lost in Mainland China."))
      .to(eq("This has been lost in China."))
    expect(described_class.normalize("A derogatory term for Mainland Chinese people."))
      .to(eq("A derogatory term for Chinese people."))
  end

  it "keeps Mainland Southeast Asia, a geographic name" do
    text = "Either Sino-Tibetan or a Mainland Southeast Asian Wanderwort."

    expect(described_class.normalize(text)).to(eq(text))
  end

  it "drops the Wiktionary placeholder left where a translation is missing" do
    expect(
      described_class.normalize(
        "First attested in 格致汇编.\n(please add an English translation of this quotation)"
      )
    )
      .to(eq("First attested in 格致匯編."))
  end

  it "is idempotent" do
    once = described_class.normalize("Phono-semantic compound (形聲 /形声): 甲(こう)状(じょう)腺(せん)")

    expect(described_class.normalize(once)).to(eq(once))
  end
end
