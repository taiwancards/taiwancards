# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::Deal do
  let(:user) { create(:user) }

  before { Current.user = user }
  after { Current.reset }

  def character(text, **data)
    create(:lexeme, kind: :character, text:, data: {"tocfl_level" => "Novice1"}.merge(data))
  end

  def word(text, **data)
    create(:lexeme, kind: :word, text:, data: {"tocfl_level" => "A1"}.merge(data))
  end

  def compose(parent, children)
    children.each_with_index do |child, index|
      LexemeLink.create!(parent:, child:, position: index)
    end

    parent
  end

  it "drills only the facets the deck asks for" do
    cards = described_class.new(user:, facets: %w[recognition]).call([word("學校").id])

    expect(cards.map(&:facet).uniq).to(eq(%w[recognition]))
  end

  it "gives a word's characters their own cards for recognition, reading and writing" do
    school = word("學校")
    compose(school, [character("學"), character("校")])

    cards = described_class.new(user:, facets: %w[recognition production reading writing]).call([school.id])
    derived = cards.select(&:derived)

    expect(derived.map(&:lexeme_id).uniq.size).to(eq(2))
    expect(derived.map(&:facet).uniq).to(match_array(%w[recognition reading writing]))
  end

  it "never drills production on a bare character" do
    school = word("學校")
    compose(school, [character("學")])

    cards = described_class.new(user:, facets: %w[recognition production]).call([school.id])

    expect(cards.select(&:derived).map(&:facet)).to(all(eq("recognition")))
  end

  it "leaves characters alone when the deck drills none of their facets" do
    school = word("學校")
    compose(school, [character("學")])

    cards = described_class.new(user:, facets: %w[production]).call([school.id])

    expect(cards.select(&:derived)).to(be_empty)
  end

  it "does not duplicate a character that is already a card in its own right" do
    hsueh = character("學")
    school = word("學校")
    compose(school, [hsueh, character("校")])

    cards = described_class.new(user:, facets: %w[recognition]).call([school.id, hsueh.id])

    expect(cards.count { |card| card.lexeme_id == hsueh.id }).to(eq(1))
  end

  it "ranks by level first, then by kind, so a character comes before the word it builds" do
    easy = character("人")
    hard = word("學校", "tocfl_level" => "B2")

    cards = described_class.new(user:, facets: %w[recognition]).call([hard.id, easy.id])
    order = Study::Ordering.new.call(cards)

    expect(order.first.lexeme_id).to(eq(easy.id))
  end

  it "reads a whole sitting in a fixed number of queries" do
    words = Array.new(40) { |index| word("詞彙#{index}") }

    report = count_queries do
      described_class.new(user:, facets: Study::CardSet::SWIPE_FACETS).call(words.map(&:id))
    end

    expect(report).to(repeat_no_query_more_than(3))
  end
end
