# frozen_string_literal: true

module Decks
  class Snapshot
    VERSION = 1
    MAX_DECKS = 50

    class << self
      def of_deck(collection)
        {"v" => VERSION, "decks" => [deck_payload(collection)]}
      end

      def of_group(group)
        decks = group
          .collections
          .order(Arel.sql("collection_group_items.position"))
          .limit(MAX_DECKS)
        {"v" => VERSION, "group" => group.name, "decks" => decks.map { |deck| deck_payload(deck) }}
      end

      def cards_in(payload)
        Array(payload["decks"]).sum { |deck| Array(deck["items"]).size }
      end

      private

      def deck_payload(collection)
        {"name" => collection.name, "facets" => collection.study_facets, "items" => rows(collection)}
      end

      def rows(collection)
        collection
          .collection_items
          .joins(:lexeme)
          .order(:position)
          .limit(Collection::MAX_ITEMS)
          .pluck("lexemes.kind", "lexemes.text")
          .map { |kind, text| [kind.to_s, text] }
      end
    end
  end
end
