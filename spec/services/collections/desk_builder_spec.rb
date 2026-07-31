# frozen_string_literal: true

require "rails_helper"

RSpec.describe Collections::DeskBuilder do
  let(:user) { create(:user) }

  before { Current.user = user }
  after { Current.reset }

  it "builds an owned manual desk from selected lexemes" do
    word = create(:lexeme, kind: :word, text: "學校")

    desk = described_class.new(user:).call(lexemes: [word])

    expect(desk.kind).to(eq("manual"))
    expect(desk.user).to(eq(user))
    expect(desk.name).to(eq("Random #1"))
    expect(desk.lexemes).to(include(word))
    expect(desk.items_count).to(eq(1))
  end

  it "leaves memory rows to the study session rather than writing one per card" do
    word = create(:lexeme, kind: :word, text: "學校")

    described_class.new(user:).call(lexemes: [word])

    expect(LexemeMemory.owned_by(user)).to(be_empty)
  end

  it "increments the Random #N name per user" do
    described_class.new(user:).call(lexemes: [])
    second = described_class.new(user:).call(lexemes: [])

    expect(second.name).to(eq("Random #2"))
  end

  it "keeps a requested name and disambiguates a collision instead of failing" do
    described_class.new(user:).call(lexemes: [], name: "Songs")
    second = described_class.new(user:).call(lexemes: [], name: "Songs")

    expect(second.name).to(eq("Songs (2)"))
  end

  it "segments pasted text into known lexemes" do
    create(:lexeme, kind: :word, text: "學校")

    desk = described_class.new(user:).call(text: "我去學校")

    expect(desk.lexemes.map(&:text)).to(include("學校"))
  end

  it "writes a whole deck in a constant number of queries" do
    words = Array.new(40) { |index| create(:lexeme, kind: :word, text: "詞彙#{index}") }

    report = count_queries { described_class.new(user:).call(lexemes: words, name: "Bulk") }

    expect(report.count).to(be <= 6)
  end

  it "caps a desk at the maximum card count" do
    words = Array.new(3) { |index| create(:lexeme, kind: :word, text: "上限#{index}") }
    stub_const("Collection::MAX_ITEMS", 2)

    desk = described_class.new(user:).call(lexemes: words)

    expect(desk.items_count).to(eq(2))
  end
end
