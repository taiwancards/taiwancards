# frozen_string_literal: true

module Decks
  class Restore
    Result = Data.define(:decks, :group, :cards, :skipped)

    EMPTY = Result.new(decks: [], group: nil, cards: 0, skipped: 0)

    def initialize(user, only_new: false)
      @user = user
      @only_new = only_new
    end

    def call(payload, group_name: nil)
      entries = Array(payload["decks"]).first(Snapshot::MAX_DECKS)
      return EMPTY if entries.empty?

      index = Resolver.new.call(entries)
      per_deck = entries.map { |entry| [entry, Resolver.ids_for(entry, index)] }
      excluded = excluded_ids(per_deck.flat_map(&:last).uniq)
      built = per_deck.filter_map { |entry, ids| build(entry, ids - excluded.to_a) }

      Result.new(
        decks: built.map(&:first),
        group: group_for(group_name || payload["group"], built.map(&:first)),
        cards: built.sum { |row| row[1] },
        skipped: per_deck.sum { |_, ids| ids.size } - built.sum { |row| row[1] }
      )
    end

    private

    def excluded_ids(ids)
      return Set.new unless @only_new

      Collections::Coverage.new(@user).covered_ids(ids)
    end

    def build(entry, ids)
      return if ids.empty?

      deck = Collections::DeskBuilder.new(user: @user).call(
        lexeme_ids: ids,
        name: entry["name"],
        facets: entry["facets"]
      )
      [deck, deck.items_count]
    end

    def group_for(name, decks)
      return if name.blank? || decks.empty?

      group = Collections::GroupBuilder.new(user: @user).call(name:)
      group.add_collections(decks.map(&:id))
      group
    end
  end
end
