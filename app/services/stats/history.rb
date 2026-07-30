# frozen_string_literal: true

module Stats
  class History
    FACET_ORDER = %w[recognition production reading tone writing].freeze
    MATURE_DAYS = 21.0

    Bucket = Struct.new(:key, :reviews, :entities, keyword_init: true)

    def initialize(now: Time.current)
      @now = now
    end

    def ranges
      {
        "today" => [@now.beginning_of_day, nil],
        "yesterday" => [(@now - 1.day).beginning_of_day, @now.beginning_of_day],
        "week" => [@now.beginning_of_day - 6.days, nil],
        "month" => [@now.beginning_of_day - 29.days, nil],
        "all" => [nil, nil]
      }
    end

    def buckets
      clauses = ranges.map { |key, (since, before)| [key, bounds(since, before)] }
      selects = clauses.flat_map do |_key, clause|
        [
          Arel.sql("count(*) FILTER (WHERE #{clause})"),
          Arel.sql("count(DISTINCT lexeme_reviews.lexeme_id) FILTER (WHERE #{clause})")
        ]
      end

      counted = Array(window(nil, nil).pick(*selects))
      clauses.each_with_index.map do |(key, _), index|
        Bucket.new(key:, reviews: counted[index * 2].to_i, entities: counted[(index * 2) + 1].to_i)
      end
    end

    def summary(range)
      since, before = ranges.fetch(range, ranges["today"])
      scope = window(since, before)
      by_rating = scope.group(:rating).count
      total = by_rating.values.sum
      good = by_rating[3].to_i + by_rating[4].to_i
      {
        total:,
        entities: scope.distinct.count(:lexeme_id),
        again: by_rating[1].to_i,
        hard: by_rating[2].to_i,
        good: by_rating[3].to_i,
        easy: by_rating[4].to_i,
        accuracy: total.zero? ? nil : (100.0 * good / total).round
      }
    end

    def entries(range, limit: 200)
      since, before = ranges.fetch(range, ranges["today"])
      scope = window(since, before)
      recent_ids = scope
        .order(reviewed_at: :desc)
        .limit(limit * FACET_ORDER.size)
        .pluck(:lexeme_id)
        .uniq
        .first(limit)
      return [] if recent_ids.empty?

      rows = scope.where(lexeme_id: recent_ids).includes(:lexeme).order(reviewed_at: :desc).to_a
      owned = memories_for(recent_ids)

      rows
        .group_by(&:lexeme_id)
        .map do |id, reviews|
          lexeme = reviews.first.lexeme
          facets = reviews.group_by(&:facet).map do |facet, facet_reviews|
            memory = owned[[id, facet]]
            {
              facet:,
              count: facet_reviews.size,
              last_rating: facet_reviews.first.rating,
              strength: strength(memory),
              memory:
            }
          end

          {
            lexeme:,
            last_reviewed_at: reviews.first.reviewed_at,
            reps: reviews.size,
            facets: facets.sort_by { |facet| FACET_ORDER.index(facet[:facet]) || 9 }
          }
        end
        .sort_by { |entry| entry[:last_reviewed_at] }
        .reverse
        .first(limit)
    end

    OVERVIEW = {
      strong: "state = :review AND stability >= :mature",
      familiar: "state = :review AND stability < :mature",
      learning: "state = :learning",
      weak: "state = :relearning",
      due: "state <> :unseen AND due_at <= :now"
    }.freeze

    def overview
      selects = OVERVIEW.values.map do |clause|
        Arel.sql("count(*) FILTER (WHERE #{ActiveRecord::Base.sanitize_sql_array([clause, overview_binds])})")
      end

      counted = Array(LexemeMemory.active.owned_by(Current.user).pick(*selects))
      OVERVIEW.keys.each_with_index.to_h { |key, index| [key, counted[index].to_i] }
    end

    def strength(memory)
      return :new if memory.nil? || memory.state == "unseen"
      return :weak if memory.state == "relearning"
      return :learning if memory.state == "learning"
      return :strong if memory.stability.to_f >= MATURE_DAYS

      :familiar
    end

    private

    def overview_binds
      {
        mature: MATURE_DAYS,
        now: @now,
        **LexemeMemory.states.symbolize_keys
      }
    end

    def bounds(since, before)
      parts = []
      parts << ActiveRecord::Base.sanitize_sql_array(["lexeme_reviews.reviewed_at >= ?", since]) if since
      parts << ActiveRecord::Base.sanitize_sql_array(["lexeme_reviews.reviewed_at < ?", before]) if before
      parts.presence&.join(" AND ") || "TRUE"
    end

    def memories_for(lexeme_ids)
      LexemeMemory
        .owned_by(Current.user)
        .where(lexeme_id: lexeme_ids)
        .index_by { |memory| [memory.lexeme_id, memory.facet] }
    end

    def window(since, before)
      scope = LexemeReview.owned_by(Current.user).joins(:lexeme)
      scope = scope.where("reviewed_at >= ?", since) if since
      scope = scope.where("reviewed_at < ?", before) if before
      scope
    end
  end
end
