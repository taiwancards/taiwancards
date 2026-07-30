# frozen_string_literal: true

module Study
  class PlanCalculator
    MINUTES_PER_NEW_ITEM = 1.5
    KINDS = %w[character word phrase].freeze

    def initialize(plan, now: Date.current)
      @plan = plan
      @now = now
    end

    def collections
      @collections ||= scope_collections
    end

    def scope_lexeme_ids
      @scope_lexeme_ids ||= CollectionItem.where(collection: collections).distinct.pluck(:lexeme_id)
    end

    def total
      scope_lexeme_ids.size
    end

    def known
      learned_ids.size
    end

    def remaining
      [total - known, 0].max
    end

    def days_left
      [(@plan.target_date - @now).to_i, 1].max
    end

    def daily_new_quota
      return 0 if remaining.zero?

      (remaining / days_left.to_f).ceil
    end

    def est_minutes_per_day
      (daily_new_quota * MINUTES_PER_NEW_ITEM).ceil
    end

    def remaining_by_kind
      ids = scope_lexeme_ids - learned_ids
      KINDS.index_with { |kind| Lexeme.where(id: ids, kind:).count }
    end

    private

    def learned_ids
      @learned_ids ||= LexemeMemory
        .owned_by(@plan.user)
        .state_review
        .where(lexeme_id: scope_lexeme_ids)
        .distinct
        .pluck(:lexeme_id)
    end

    def scope_collections
      target = Collection.where(kind: :tocfl).find_by(level_tag: @plan.target_level)
      return Collection.none if target.nil?

      Collection.where(kind: :tocfl).where(position: ..target.position)
    end
  end
end
