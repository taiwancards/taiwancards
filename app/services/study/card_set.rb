# frozen_string_literal: true

module Study
  class CardSet
    SWIPE_FACETS = %w[recognition production reading listening].freeze
    OPT_IN_FACETS = %w[tone writing].freeze
    SESSION_FACETS = (SWIPE_FACETS + OPT_IN_FACETS).freeze
    COLLECTION_CAP = 200
    EVERYDAY_SHARE = 0.25

    def initialize(now: Time.current, settings: Setting.instance)
      @now = now
      @settings = settings
      @facets = SWIPE_FACETS
    end

    attr_reader :facets

    def build(mode:, size: nil, collection: nil)
      tokens(select(mode:, size:, collection:))
    end

    def select(mode:, size: nil, collection: nil)
      @facets = swipe_facets_for(collection)
      case mode
      when "cram"
        cram_ids(size, collection)
      when "collection"
        collection_ids(collection)
      when "desk"
        desk_ids(collection)
      when "redo"
        redo_ids(collection)
      when "today"
        today_ids
      else
        daily_ids(size)
      end
    end

    def today_ids
      plan = StudyPlan.find_by(user: Current.user)
      due = due_lexeme_ids
      quota = today_quota
      fresh = plan ? plan_scoped_fresh_ids(plan, quota) : fresh_lexeme_ids(quota)
      activate(fresh)
      (due + fresh).uniq
    end

    def desk_ids(collection)
      return [] unless collection

      member_ids = collection.lexemes.limit(COLLECTION_CAP).pluck(:id).to_set
      due = due_lexeme_ids.select { |id| member_ids.include?(id) }
      fresh = collection
        .collection_items
        .where
        .not(lexeme_id: (studied_lexeme_ids + due))
        .order(:position)
        .limit(today_quota)
        .pluck(:lexeme_id)
      activate(fresh)
      (due + fresh).uniq
    end

    def redo_ids(collection)
      return [] unless collection

      ids = collection.lexemes.limit(COLLECTION_CAP).pluck(:id)
      activate(ids)
      ids
    end

    def tokens(lexeme_ids, facets: @facets)
      lexeme_ids = lexeme_ids.uniq
      present = LexemeMemory
        .active
        .owned_by(Current.user)
        .where(lexeme_id: lexeme_ids, facet: facets.map { |facet| LexemeMemory.facets[facet] })
        .pluck(:lexeme_id, :facet)
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last) }

      out = []
      facets.each do |facet|
        lexeme_ids.each do |id|
          out << "#{id}:#{facet}" if present[id]&.include?(facet)
        end
      end

      out
    end

    private

    def swipe_facets_for(collection)
      toggled = collection&.study_facets
      return SWIPE_FACETS if toggled.blank?

      SESSION_FACETS & toggled
    end

    def facet_ints
      @facets.map { |facet| LexemeMemory.facets[facet] }
    end

    def horizon
      @now + (@settings.learn_ahead_minutes * 60)
    end

    def daily_ids(size)
      size = (size.presence || @settings.session_size).to_i
      ids = due_lexeme_ids.first(size)
      ids += unseen_lexeme_ids(exclude: ids).first(size - ids.size) if ids.size < size
      if ids.size < size
        fresh = fresh_lexeme_ids(size - ids.size)
        activate(fresh)
        ids += fresh
      end

      ids.uniq.first(size)
    end

    def unseen_lexeme_ids(exclude: [])
      scope = LexemeMemory
        .active
        .owned_by(Current.user)
        .joins(:lexeme)
        .where(facet: facet_ints, state: LexemeMemory.states[:unseen])
        .order(
          Arel.sql(
            "#{Lexeme::LEVEL_INDEX_SQL} NULLS LAST, " \
              "#{Lexeme::FREQ_RANK_SQL} NULLS LAST, " \
              "#{Lexeme::MOE_INDEX_SQL} NULLS LAST"
          ),
          :lexeme_id
        )
      scope = scope.where.not(lexeme_id: exclude) if exclude.any?
      scope.pluck(:lexeme_id).uniq
    end

    def cram_ids(size, collection)
      size = (size.presence || @settings.session_size).to_i
      pool = collection ? collection.lexemes.pluck(:id) : frequency_pool_ids(size * 4)
      fresh = (pool - activated_lexeme_ids).first(size)
      activate(fresh)
      fresh
    end

    def collection_ids(collection)
      return [] unless collection

      ids = collection.lexemes.limit(COLLECTION_CAP).pluck(:id)
      activate(ids)
      ids
    end

    def today_quota
      plan = StudyPlan.find_by(user: Current.user)
      plan ? Study::PlanCalculator.new(plan).daily_new_quota : @settings.session_size.to_i
    end

    def due_lexeme_ids
      LexemeMemory
        .active
        .owned_by(Current.user)
        .where(facet: facet_ints)
        .where
        .not(state: :unseen)
        .where(due_at: ..horizon)
        .order(:due_at)
        .pluck(:lexeme_id)
        .uniq
    end

    def fresh_lexeme_ids(count)
      return [] if count <= 0

      everyday = everyday_fresh_ids((count * EVERYDAY_SHARE).round)
      remaining = count - everyday.size
      return everyday if remaining <= 0

      rest = (frequency_pool_ids(remaining * 4) - activated_lexeme_ids - everyday).first(remaining)
      everyday + rest
    end

    def everyday_fresh_ids(count)
      return [] if count <= 0

      Lexeme
        .unrestricted
        .where("lexemes.data->>'taiwan_only' = 'true' AND lexemes.data->>'tier' = '1'")
        .where
        .not(id: activated_lexeme_ids)
        .order(Arel.sql("#{Lexeme::FREQ_RANK_SQL} NULLS LAST"), :id)
        .limit(count)
        .pluck(:id)
    end

    def plan_scoped_fresh_ids(plan, count)
      return [] if count <= 0

      scope_ids = Study::PlanCalculator.new(plan).scope_lexeme_ids
      Lexeme
        .where(id: scope_ids)
        .where
        .not(id: activated_lexeme_ids)
        .curriculum_order
        .limit(count)
        .pluck(:id)
    end

    def frequency_pool_ids(limit)
      scope = Lexeme.where(kind: %i[character word])
      ceiling = level_ceiling
      scope = scope.up_to_level(ceiling) if ceiling
      ids = scope.curriculum_order.limit(limit).pluck(:id)
      return ids if ids.size >= limit || ceiling.nil?

      ids +
        Lexeme
          .where(kind: %i[character word])
          .where
          .not(id: ids)
          .curriculum_order
          .limit(limit - ids.size)
          .pluck(:id)
    end

    def level_ceiling
      user = Current.user
      return nil unless user.respond_to?(:level_grade)

      user.level_grade + 1
    end

    def studied_lexeme_ids
      @studied_lexeme_ids ||= LexemeMemory
        .active
        .owned_by(Current.user)
        .where
        .not(state: :unseen)
        .distinct
        .pluck(:lexeme_id)
    end

    def activated_lexeme_ids
      @activated_lexeme_ids ||= LexemeMemory.active.owned_by(Current.user).distinct.pluck(:lexeme_id)
    end

    def activate(ids)
      return if ids.blank?

      Lexemes::Activator.new(now: @now).call_many(Lexeme.where(id: ids).to_a)
    end
  end
end
