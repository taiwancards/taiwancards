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

  it "leaves a clean dictionary alone" do
    word("捷運", "From 捷 (“swift”) + 運 (“transport”).")

    expect(described_class.new).not_to(be_drift)
  end
end
