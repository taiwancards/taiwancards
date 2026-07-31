# frozen_string_literal: true

require "rails_helper"

RSpec.describe Study::Ordering do
  def card(lexeme_id, facet, difficulty: [1, 1, 1, 1], familiarity: 0.0, derived: false)
    Study::Ordering::Card.new(lexeme_id:, facet:, difficulty:, familiarity:, derived:)
  end

  def deck(words:, facets:)
    (1..words).flat_map do |id|
      facets.map { |facet| card(id, facet, difficulty: [1, 1, id, 1]) }
    end
  end

  it "returns nothing for nothing" do
    expect(described_class.new.call([])).to(eq([]))
  end

  it "never asks two things about the same word in a row" do
    order = described_class.new.call(deck(words: 8, facets: %w[recognition production reading listening]))

    expect(order.each_cons(2).count { |a, b| a.lexeme_id == b.lexeme_id }).to(eq(0))
  end

  it "never asks the same facet twice in a row" do
    order = described_class.new.call(deck(words: 8, facets: %w[recognition production reading listening]))

    expect(order.each_cons(2).count { |a, b| a.facet == b.facet }).to(eq(0))
  end

  it "keeps every card exactly once" do
    cards = deck(words: 6, facets: %w[recognition production reading])
    order = described_class.new.call(cards)

    expect(order.map(&:token).sort).to(eq(cards.map(&:token).sort))
  end

  it "opens with the easiest word" do
    hard = card(2, "recognition", difficulty: [5, 1, 4, 2])
    easy = card(1, "recognition", difficulty: [1, 1, 0, 1])

    expect(described_class.new.call([hard, easy]).first.lexeme_id).to(eq(1))
  end

  it "works through the words in difficulty order within the first pass" do
    order = described_class.new.call(deck(words: 5, facets: %w[recognition production]))

    expect(order.first(5).map(&:lexeme_id)).to(eq([1, 2, 3, 4, 5]))
  end

  it "gives each word a different starting facet so the pass is not monotonous" do
    order = described_class.new.call(deck(words: 4, facets: %w[recognition production reading listening]))

    expect(order.first(4).map(&:facet).uniq.size).to(eq(4))
  end

  it "still covers every facet of every word by the end" do
    facets = %w[recognition production reading]
    order = described_class.new.call(deck(words: 4, facets:))

    order.group_by(&:lexeme_id).each_value { |cards| expect(cards.map(&:facet)).to(match_array(facets)) }
  end

  it "copes with words that carry different numbers of facets" do
    cards = [
      card(1, "recognition", difficulty: [1, 1, 1, 1]),
      card(1, "reading", difficulty: [1, 1, 1, 1]),
      card(2, "recognition", difficulty: [1, 1, 2, 1]),
      card(3, "recognition", difficulty: [1, 1, 3, 1]),
      card(3, "reading", difficulty: [1, 1, 3, 1]),
      card(3, "writing", difficulty: [1, 1, 3, 1])
    ]

    order = described_class.new.call(cards)

    expect(order.map(&:token).sort).to(eq(cards.map(&:token).sort))
    expect(order.first(3).map(&:lexeme_id)).to(eq([1, 2, 3]))
  end

  it "only repeats a word once the others have run out" do
    cards = [card(1, "recognition"), card(2, "recognition"), card(2, "reading"), card(2, "writing")]

    order = described_class.new.call(cards)
    repeats = order.each_cons(2).count { |a, b| a.lexeme_id == b.lexeme_id }

    expect(order.first(2).map(&:lexeme_id).uniq.size).to(eq(2))
    expect(repeats).to(eq(2))
  end

  it "gives the same order however the cards arrive" do
    cards = deck(words: 7, facets: %w[recognition production reading])

    expect(described_class.new.call(cards.shuffle).map(&:token)).to(eq(described_class.new.call(cards).map(&:token)))
  end

  it "orders a full sitting quickly" do
    cards = (1..250).flat_map do |id|
      %w[recognition production reading listening].map { |facet| card(id, facet, difficulty: [id % 7, 1, id, 2]) }
    end

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    order = described_class.new.call(cards)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(order.size).to(eq(1_000))
    expect(elapsed).to(be < 0.3)
  end
end
