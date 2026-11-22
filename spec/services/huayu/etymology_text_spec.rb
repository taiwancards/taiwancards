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

  it "drops the redirect Wiktionary prints where a character only points to another entry" do
    text = "For pronunciation and definitions of 回 – see 迴 (“to revolve; to rotate; to avoid; etc.”).\n" \
      "(This character is the simplified and variant form of 迴).\n Notes:\n" \
      "Simplified Chinese is mainly used in China, Malaysia, and Singapore.\n" \
      "Traditional Chinese is mainly used in Hong Kong, Macau, and Taiwan."

    expect(described_class.normalize(text)).to(eq(""))
  end

  it "keeps what follows a redirect" do
    text = "For pronunciation and definitions of 蕉 – see 𣟼.\n(This character is a variant form of 𣟼).\nOnomatopoeic."

    expect(described_class.normalize(text)).to(eq("Onomatopoeic."))
  end

  it "turns a wiki definition list into plain lines" do
    text = "Pictogram (象形).\n;child\n:From Proto-Sino-Tibetan *tsəʔ (“child”).\n:* Compare 字.\n;first earthly branch\n" \
      ":Smith (2011) proposes 甾."

    expect(described_class.normalize(text)).to(
      eq(
        "Pictogram (象形).\nchild:\nFrom Proto-Sino-Tibetan *tsəʔ (“child”).\n* Compare 字.\n" \
          "first earthly branch:\nSmith (2011) proposes 甾."
      )
    )
  end

  it "drops sense headings that nothing follows and a colon left where a quotation was" do
    text = "Phono-semantic compound (形聲): semantic 木 + phonetic 羕.\nciting a passage:\n:\n; “appearance; etc.”\n; “-sama”"

    expect(described_class.normalize(text)).to(
      eq("Phono-semantic compound (形聲): semantic 木 + phonetic 羕.\nciting a passage:")
    )
  end

  it "drops the placeholders for a missing script or term and a bare link" do
    text = "Compare Jingpho [script needed] (pyau, “fly”), Mizo [Term?] (puŋᴴ) https://example.com/birds/."

    expect(described_class.normalize(text)).to(eq("Compare Jingpho (pyau, “fly”), Mizo (puŋᴴ)."))
  end

  it "is idempotent" do
    once = described_class.normalize("Phono-semantic compound (形聲 /形声): 甲(こう)状(じょう)腺(せん)")

    expect(described_class.normalize(once)).to(eq(once))
  end

  it "is idempotent on a definition list" do
    once = described_class.normalize("Pictogram.\n;child\n:From *tsəʔ.\n::* Compare 字.\n; “to return”")

    expect(described_class.normalize(once)).to(eq(once))
  end
end
