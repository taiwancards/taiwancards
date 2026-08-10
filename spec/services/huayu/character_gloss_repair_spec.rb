# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::CharacterGlossRepair do
  def character(text, meanings, senses)
    lexeme = Lexeme.create!(kind: :character, text: text, meanings: meanings, readings: {"pinyin" => "lí"})
    senses.each_with_index do |sense, position|
      LexemeSense.create!(lexeme: lexeme, position: position, meanings: sense)
    end

    lexeme
  end

  it "rebuilds a headline that its own senses contradict" do
    lexeme = character(
      "離",
      {"en" => "rare beast; strange; elegant", "ru" => "редкий зверь; странный; изящный"},
      [
        {"en" => "to part, to separate", "ru" => "расставаться, разделяться"},
        {"en" => "to be apart from", "ru" => "отстоять от"}
      ]
    )

    result = described_class.new(tainted: {"離" => "rare beast; strange; elegant"}).call

    expect(result.repaired).to(eq(1))
    expect(lexeme.reload.meanings["en"]).to(eq("to part, to separate; to be apart from"))
    expect(lexeme.meanings["ru"]).to(eq("расставаться, разделяться; отстоять от"))
  end

  it "leaves a headline its senses agree with" do
    lexeme = character(
      "價",
      {"en" => "price, value", "ru" => "цена"},
      [{"en" => "price, what a thing costs", "ru" => "цена, денежная стоимость"}]
    )

    expect(described_class.new(tainted: {"價" => "price, value"}).call.repaired).to(eq(0))
    expect(lexeme.reload.meanings["en"]).to(eq("price, value"))
  end

  it "leaves a character whose headline is not the tainted gloss" do
    lexeme = character("龜", {"en" => "turtle"}, [{"en" => "a tortoise or turtle"}])

    expect(described_class.new(tainted: {"龜" => "something else entirely"}).call.repaired).to(eq(0))
    expect(lexeme.reload.meanings["en"]).to(eq("turtle"))
  end

  it "skips senses that only describe a literary register" do
    lexeme = character(
      "幹",
      {"en" => "arid, dry", "ru" => "сухой"},
      [
        {"en" => "literary: the wooden frame boards of a wall", "ru" => "книжн.: опорные доски"},
        {"en" => "the trunk, the main body", "ru" => "ствол, основная часть"}
      ]
    )

    described_class.new(tainted: {"幹" => "arid, dry"}).call

    expect(lexeme.reload.meanings["en"]).to(eq("the trunk, the main body"))
  end

  it "leaves characters whose senses describe another reading" do
    lexeme = character("台", {"en" => "platform; unit"}, [{"en" => "I, me"}])

    expect(described_class.new(tainted: {"台" => "platform; unit"}).call.repaired).to(eq(0))
    expect(lexeme.reload.meanings["en"]).to(eq("platform; unit"))
  end

  it "reports drift only while something needs repairing" do
    character("離", {"en" => "rare beast"}, [{"en" => "to part, to separate"}])

    expect(described_class.new(tainted: {"離" => "rare beast"})).to(be_drift)
    described_class.new(tainted: {"離" => "rare beast"}).call
    expect(described_class.new(tainted: {"離" => "rare beast"})).not_to(be_drift)
  end
end
