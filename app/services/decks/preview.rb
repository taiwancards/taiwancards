# frozen_string_literal: true

module Decks
  class Preview
    Deck = Data.define(:name, :cards, :covered) do
      def fresh = cards - covered

      def covered_percent = cards.zero? ? 0 : ((covered * 100.0) / cards).round
    end

    Result = Data.define(:decks, :group, :cards, :coverage) do
      def overlapping? = coverage.overlapping?

      def fresh = coverage.fresh

      def covered_percent = coverage.covered_percent
    end

    def initialize(user)
      @user = user
    end

    def call(payload)
      entries = Array(payload["decks"]).first(Snapshot::MAX_DECKS)
      index = Resolver.new.call(entries)
      per_deck = entries.map { |entry| [entry, Resolver.ids_for(entry, index)] }
      union = per_deck.flat_map(&:last).uniq
      coverage = Collections::Coverage.new(@user).call(union)

      Result.new(
        decks: per_deck.map { |entry, ids| deck_for(entry, ids, coverage.covered) },
        group: payload["group"],
        cards: union.size,
        coverage:
      )
    end

    private

    def deck_for(entry, ids, covered)
      Deck.new(name: entry["name"], cards: ids.size, covered: ids.count { |id| covered.include?(id) })
    end
  end
end
