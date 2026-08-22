# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CangjieRepair do
  def character(text, code)
    Lexeme.create!(kind: :character, text:, meanings: {}, data: {"cangjie" => code})
  end

  it "replaces a code the fifth generation superseded" do
    lexeme = character("修", "olhh")

    expect(described_class.new.call.repaired).to(eq(1))
    expect(lexeme.reload.data["cangjie"]).to(eq("oloh"))
  end

  it "keeps the rest of the stored data" do
    lexeme = Lexeme.create!(
      kind: :character,
      text: "凳",
      meanings: {"en" => "stool"},
      data: {"cangjie" => "nomrn", "strokes" => 14}
    )

    described_class.new.call

    expect(lexeme.reload.data).to(include("cangjie" => "nthn", "strokes" => 14))
    expect(lexeme.meanings["en"]).to(eq("stool"))
  end

  it "leaves a dictionary that already types the fifth generation alone" do
    Huayu::Cangjie::SUPERSEDED.each { |text, code| character(text, code) }

    expect(described_class.new).not_to(be_drift)
  end

  it "repairs every character the fifth generation recoded" do
    Huayu::Cangjie::SUPERSEDED.each_key { |text| character(text, "wrong") }

    expect(described_class.new.call.repaired).to(eq(Huayu::Cangjie::SUPERSEDED.size))
    expect(Lexeme.where(kind: :character).pluck(:text, Arel.sql("data->>'cangjie'")).to_h)
      .to(eq(Huayu::Cangjie::SUPERSEDED.to_h))
  end
end
