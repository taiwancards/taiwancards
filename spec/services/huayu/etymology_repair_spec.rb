# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::EtymologyRepair do
  def word(text, etymology)
    Lexeme.create!(kind: :word, text:, meanings: {}, data: {"etymology_text" => etymology})
  end

  it "rewrites an etymology that carries simplified characters" do
    lexeme = word("臺獨", "Short for 臺灣獨立運動／台湾独立运动 (Táiwān dúlì yùndòng).")

    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.data["etymology_text"]).to(eq("Short for 臺灣獨立運動 (Táiwān dúlì yùndòng)."))
  end

  it "keeps the rest of the stored data" do
    lexeme = Lexeme.create!(
      kind: :word,
      text: "保庇",
      meanings: {"en" => "to bless"},
      data: {"etymology_text" => "From Hokkien 保庇／保庇 (pó-pì).", "taiwan_specific" => true}
    )

    described_class.new.call

    expect(lexeme.reload.data["taiwan_specific"]).to(be(true))
    expect(lexeme.meanings["en"]).to(eq("to bless"))
  end

  it "removes an etymology that is only a sense label" do
    lexeme = word("保險", "\"insurance\"")

    expect(described_class.new).to(be_drift)
    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.data).not_to(have_key("etymology_text"))
    expect(Huayu::WordProfile.new(lexeme, user: nil).etymology).to(be_nil)
    expect(described_class.new).not_to(be_drift)
  end

  it "removes a translated sense label and keeps the real translations" do
    lexeme = Lexeme.create!(
      kind: :word,
      text: "傳真",
      meanings: {},
      data: {
        "etymology_text" => "From 傳 (“to transmit”) + 真 (“true image”).",
        "etymology_i18n" => {
          "vi" => {"text" => "“bản fax”"},
          "ind" => {"hint" => "kirim", "text" => "“faks”"},
          "de" => {"text" => "Aus 傳 („übertragen“) + 真 („wahres Bild“)."}
        }
      }
    )

    expect(described_class.new).to(be_drift)
    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.data["etymology_text"]).to(eq("From 傳 (“to transmit”) + 真 (“true image”)."))
    expect(lexeme.data["etymology_i18n"]).to(
      eq({"ind" => {"hint" => "kirim"}, "de" => {"text" => "Aus 傳 („übertragen“) + 真 („wahres Bild“)."}})
    )
    expect(described_class.new).not_to(be_drift)
  end

  it "drops the translations once only sense labels were left in them" do
    lexeme = Lexeme.create!(
      kind: :word,
      text: "出口",
      meanings: {},
      data: {"etymology_i18n" => {"vi" => {"text" => "“lối ra”"}, "ind" => {"text" => "“pintu keluar”"}}}
    )

    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.data).not_to(have_key("etymology_i18n"))
    expect(lexeme.data).not_to(have_key("etymology_text"))
  end

  it "leaves a clean dictionary alone" do
    word("捷運", "From 捷 (“swift”) + 運 (“transport”).")

    expect(described_class.new).not_to(be_drift)
  end
end
