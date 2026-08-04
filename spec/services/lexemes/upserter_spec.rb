# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lexemes::Upserter do
  subject(:upserter) { described_class.new }

  it "creates a word when the dictionary has never seen the text" do
    lexeme = upserter.word("珍奶", readings: {"pinyin" => "zhēnnǎi"})

    expect(lexeme.kind).to(eq("word"))
    expect(lexeme.readings["pinyin"]).to(eq("zhēnnǎi"))
  end

  it "updates the entry a classifier has since moved to collocation, instead of making a second one" do
    existing = create(:lexeme, kind: :collocation, text: "超商", meanings: {"en" => "convenience store"})

    lexeme = upserter.word("超商", readings: {"pinyin" => "chāoshāng"})

    expect(lexeme.id).to(eq(existing.id))
    expect(lexeme.kind).to(eq("collocation"))
    expect(Lexeme.where(text: "超商").count).to(eq(1))
  end

  it "prefers the word when a text somehow exists under both kinds" do
    word = create(:lexeme, kind: :word, text: "小七")
    create(:lexeme, kind: :collocation, text: "小七")

    expect(upserter.word("小七").id).to(eq(word.id))
  end

  it "keeps other kinds to themselves" do
    create(:lexeme, kind: :collocation, text: "看書")

    character = upserter.character("看書")

    expect(character.kind).to(eq("character"))
    expect(Lexeme.where(text: "看書").count).to(eq(2))
  end
end
