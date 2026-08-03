# frozen_string_literal: true

module Study
  class MistakeBook
    WINDOW = 7.days
    CAP = 60

    def initialize(user, now: Time.current)
      @user = user
      @now = now
    end

    def lexeme_ids
      @lexeme_ids ||= LexemeReview
        .owned_by(@user)
        .where(rating: Fsrs::Scheduler::RATINGS.fetch(:again))
        .where(reviewed_at: (@now - WINDOW)..)
        .order(reviewed_at: :desc)
        .pluck(:lexeme_id)
        .uniq
        .first(CAP)
    end

    def lexemes
      @lexemes ||= begin
        by_id = Lexeme.where(id: lexeme_ids).index_by(&:id)
        lexeme_ids.filter_map { |id| by_id[id] }
      end
    end

    def count = lexeme_ids.size

    def any? = count.positive?

    def forecast
      @forecast ||= begin
        today_end = @now.end_of_day
        {
          today: due_scope.where(due_at: ..today_end).count,
          tomorrow: due_scope.where(due_at: today_end..(today_end + 1.day)).count,
          week: due_scope.where(due_at: ..(today_end + 6.days)).count
        }
      end
    end

    private

    def due_scope
      LexemeMemory
        .active
        .owned_by(@user)
        .joins(:lexeme)
        .where(facet: Study::CardSet::SWIPE_FACETS.map { |facet| LexemeMemory.facets[facet] })
        .where
        .not(state: :unseen)
        .distinct
    end
  end
end
