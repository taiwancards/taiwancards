# frozen_string_literal: true

module Decks
  class Sharing
    class << self
      def publish_deck(collection, user:)
        payload = Snapshot.of_deck(collection)
        create(user:, kind: :deck, name: collection.name, payload:, decks: 1)
      end

      def publish_group(group, user:)
        payload = Snapshot.of_group(group)
        create(user:, kind: :group, name: group.name, payload:, decks: payload["decks"].size)
      end

      private

      def create(user:, kind:, name:, payload:, decks:)
        prune(user)
        DeckShare.create!(
          user:,
          kind:,
          name:,
          payload:,
          decks_count: decks,
          cards_count: Snapshot.cards_in(payload)
        )
      end

      def prune(user)
        live = DeckShare.where(user:).live.count
        return if live < DeckShare::MAX_ACTIVE_PER_USER

        stale = DeckShare
          .where(user:)
          .live
          .order(:created_at)
          .limit(live - DeckShare::MAX_ACTIVE_PER_USER + 1)
          .pluck(:id)
        DeckShare.where(id: stale).update_all(revoked_at: Time.current)
      end
    end
  end
end
