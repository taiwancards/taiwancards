# frozen_string_literal: true

module Study
  class CardSet
    SWIPE_FACETS = %w[recognition production reading listening].freeze
    OPT_IN_FACETS = %w[tone writing].freeze
    SESSION_FACETS = (SWIPE_FACETS + OPT_IN_FACETS).freeze
    SITTING_CAP = 250
    EVERYDAY_SHARE = 0.25
    GRAMMAR_SHARE = 0.15
    SENTENCE_SHARE = 0.15
    RECOMMENDED_MODES = %w[daily today].freeze

    def initialize(now: Time.current, settings: Study::Preferences.for)
      @now = now
      @settings = settings
      @facets = SWIPE_FACETS
    end

    attr_reader :facets

    def build(mode:, size: nil, collection: nil)
      tokens(select(mode:, size:, collection:))
    end

    def select(mode:, size: nil, collection: nil, offset: 0)
      @facets = swipe_facets_for(collection)
      @recommended = RECOMMENDED_MODES.include?(mode)
      ids = case mode
      when "cram"
        cram_ids(size, collection)
      when "collection", "redo"
        window_ids(collection, offset)
      when "desk"
        desk_ids(collection)
      when "today"
        today_ids
      when "mistakes"
        mistake_ids
      else
        daily_ids(size)
      end

      activate_cards(ids)
      ids
    end

    def window_ids(collection, offset = 0)
      return [] unless collection

      ids = collection.ordered_lexeme_ids(limit: SITTING_CAP, offset: offset)
      activate(ids)
      ids
    end

    def today_ids
      plan = StudyPlan.find_by(user: Current.user)
      due = due_lexeme_ids
      quota = today_quota
      ration = @recommended ? ration_ids(quota, exclude: due) : []
      room = quota - ration.size
      fresh = plan ? plan_scoped_fresh_ids(plan, room) : fresh_lexeme_ids(room)
      activate(fresh)
      (due + ration + fresh).uniq
    end

    def desk_ids(collection)
      return [] unless collection

      member_ids = collection.ordered_lexeme_ids.to_set
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

    def tokens(lexeme_ids, facets: @facets)
      Ordering.new.call(deal(lexeme_ids, facets)).map(&:token)
    end

    def deal(lexeme_ids, facets = @facets)
      Deal.new(user: Current.user, facets:).call(lexeme_ids)
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
      ids += ration_ids(size - ids.size, exclude: ids) if @recommended && ids.size < size
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

    def mistake_ids
      MistakeBook.new(Current.user, now: @now).lexeme_ids
    end

    def cram_ids(size, collection)
      size = (size.presence || @settings.session_size).to_i
      pool = collection ? collection.ordered_lexeme_ids : frequency_pool_ids(size * 4)
      fresh = (pool - activated_lexeme_ids).first(size)
      activate(fresh)
      fresh
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

    def ration_ids(room, exclude: [])
      return [] if room <= 0

      grammar = grammar_fresh_ids((room * GRAMMAR_SHARE).round.clamp(0, room), exclude:)
      sentences = sentence_fresh_ids(
        (room * SENTENCE_SHARE).round.clamp(0, room - grammar.size),
        exclude: exclude + grammar
      )
      picked = grammar + sentences
      activate(picked)
      picked
    end

    def fresh_lexeme_ids(count)
      return [] if count <= 0

      everyday = everyday_fresh_ids((count * EVERYDAY_SHARE).round)
      remaining = count - everyday.size
      return everyday if remaining <= 0

      everyday + (frequency_pool_ids(remaining * 4) - activated_lexeme_ids - everyday).first(remaining)
    end

    def grammar_fresh_ids(count, exclude: [])
      return [] if count <= 0

      scope = Lexeme.where(kind: :grammar).where.not(id: activated_lexeme_ids + exclude)
      ceiling = level_ceiling
      scope = scope.up_to_level(ceiling) if ceiling
      scope.curriculum_order.limit(count).pluck(:id)
    end

    def sentence_fresh_ids(count, exclude: [])
      return [] if count <= 0

      known = LexemeMemory.owned_by(Current.user).state_review.select(:lexeme_id)
      scope = Lexeme
        .where(kind: :sentence, restricted: false)
        .where("lexemes.data ? 'audio'")
        .where("lexemes.meanings ? :locale", locale: I18n.locale.to_s)
        .where
        .not(id: activated_lexeme_ids + exclude)
        .where(
          "NOT EXISTS (SELECT 1 FROM sentence_words sw WHERE sw.sentence_id = lexemes.id " \
            "AND sw.lexeme_id NOT IN (#{known.to_sql}))"
        )
        .where("EXISTS (SELECT 1 FROM sentence_words sw WHERE sw.sentence_id = lexemes.id)")
      ceiling = level_ceiling
      scope = scope.up_to_level(ceiling) if ceiling
      scope.order(Arel.sql("#{Lexeme::LEVEL_INDEX_SQL} NULLS LAST"), :id).limit(count).pluck(:id)
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

    def activate_cards(ids)
      cards = deal(ids)
      return if cards.empty?

      Lexemes::Activator.new(now: @now).activate_pairs(
        cards.map { |card| [card.lexeme_id, LexemeMemory.facets.fetch(card.facet)] }
      )
    end
  end
end
