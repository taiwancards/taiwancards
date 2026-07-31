# frozen_string_literal: true

module Admin
  class UserStats
    WINDOW_DAYS = 30
    WINDOW = WINDOW_DAYS.days

    EMPTY = {cards: 0, reviews: 0, decks: 0}.freeze

    def initialize(users, now: Time.current)
      @ids = Array(users).map(&:id)
      @now = now
    end

    def for(user)
      return EMPTY if ids.empty?

      {cards: cards[user.id].to_i, reviews: reviews[user.id].to_i, decks: decks[user.id].to_i}
    end

    private

    attr_reader :ids, :now

    def cards = @cards ||= tally(LexemeMemory.active)

    def reviews = @reviews ||= tally(LexemeReview.where(reviewed_at: now - WINDOW..))

    def decks = @decks ||= tally(Collection.where(kind: :manual))

    def tally(scope)
      return {} if ids.empty?

      scope.where(user_id: ids).group(:user_id).count
    end
  end
end
