# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::GlossRepair do
  it "cleans dictionary markup out of a stored gloss" do
    lexeme = create(
      :lexeme,
      kind: :word,
      text: "被子",
      meanings: {"en" => "blanket; CL:條|条[tiao2]", "ru" => "одеяло"}
    )

    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.meanings["en"]).to(eq("blanket; measure word: 條"))
    expect(lexeme.meanings["ru"]).to(eq("одеяло"))
  end

  it "leaves a clean gloss alone" do
    create(:lexeme, kind: :word, text: "捷運", meanings: {"en" => "metro", "ru" => "метро"})

    expect(described_class.new).not_to(be_drift)
  end
end
