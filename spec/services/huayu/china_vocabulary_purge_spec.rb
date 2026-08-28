# frozen_string_literal: true

require "rails_helper"

RSpec.describe Huayu::ChinaVocabularyPurge do
  def word(text, level: nil)
    Lexeme.create!(kind: :word, text:, data: level ? {"tocfl_level" => level} : {})
  end

  it "removes erhua vocabulary that carries a curriculum level" do
    erhua = word("一點兒", level: "B1")
    described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(erhua.id)).to(be(false))
  end

  it "keeps the Taiwan standard form" do
    plain = word("一點", level: "B1")
    described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(plain.id)).to(be(true))
  end

  it "keeps words where the final character is not an erhua suffix" do
    daughter = word("女兒", level: "Novice2")
    model = word("模特兒", level: "B2")
    described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(daughter.id)).to(be(true))
    expect(Lexeme.exists?(model.id)).to(be(true))
  end

  it "leaves untagged entries for review instead of deleting them" do
    stray = word("打盹兒")
    result = described_class.new(io: StringIO.new).call
    expect(result[:review]).to(be >= 1)
    expect(Lexeme.exists?(stray.id)).to(be(true))
  end

  it "removes a studied entry together with its memories and reviews" do
    erhua = word("差點兒", level: "B1")
    memory = LexemeMemory.create!(lexeme: erhua, user: nil, facet: :recognition, activated_at: Time.current)
    LexemeReview.create!(
      lexeme: erhua,
      lexeme_memory: memory,
      facet: :recognition,
      rating: 3,
      reviewed_at: Time.current
    )
    result = described_class.new(io: StringIO.new).call
    expect(Lexeme.exists?(erhua.id)).to(be(false))
    expect(LexemeMemory.exists?(memory.id)).to(be(false))
    expect(LexemeReview.where(lexeme_id: erhua.id)).to(be_empty)
    expect(result[:studied]).to(eq(1))
  end

  it "reports without deleting on a dry run" do
    erhua = word("邊兒", level: "Novice2")
    result = described_class.new(io: StringIO.new).call(dry_run: true)
    expect(result[:removed]).to(eq(0))
    expect(Lexeme.exists?(erhua.id)).to(be(true))
  end
end
