# frozen_string_literal: true

module Study
  class Ordering
    Card = Data.define(:lexeme_id, :facet, :difficulty, :familiarity, :derived) do
      def token = "#{lexeme_id}:#{facet}"

      def fresh? = familiarity.zero?
    end

    KIND_WEIGHT = {"character" => 0, "word" => 1, "measure_word" => 1, "collocation" => 2, "phrase" => 2}.freeze
    FACET_ORDER = %w[recognition reading listening production tone writing].freeze

    def call(cards)
      return [] if cards.empty?

      deal(hands(cards))
    end

    private

    def hands(cards)
      grouped = cards.group_by(&:lexeme_id)
      grouped
        .keys
        .sort_by { |id| [grouped[id].map(&:difficulty).min, id] }
        .each_with_index
        .map { |id, seat| rotate(grouped[id].sort_by { |card| facet_rank(card) }, seat) }
    end

    def rotate(pile, seat)
      pile.empty? ? pile : pile.rotate(seat % pile.size)
    end

    def facet_rank(card)
      [FACET_ORDER.index(card.facet) || FACET_ORDER.size, card.derived ? 1 : 0, card.facet]
    end

    def deal(piles)
      depth = piles.map(&:size).max.to_i
      (0...depth).flat_map { |round| piles.filter_map { |pile| pile[round] } }
    end
  end
end
