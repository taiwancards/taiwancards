# frozen_string_literal: true

module Collections
  class Coverage
    Report = Data.define(:total, :in_decks, :studied, :covered) do
      def fresh = total - covered.size

      def covered_percent = total.zero? ? 0 : ((covered.size * 100.0) / total).round

      def overlapping? = covered.any?
    end

    def initialize(user, except: nil)
      @user = user
      @except = except
    end

    def call(candidate_ids)
      ids = Array(candidate_ids).uniq
      return Report.new(total: 0, in_decks: Set.new, studied: Set.new, covered: Set.new) if ids.empty?

      in_decks = deck_member_ids(ids)
      studied = studied_ids(ids)
      Report.new(total: ids.size, in_decks:, studied:, covered: in_decks | studied)
    end

    def covered_ids(candidate_ids)
      call(candidate_ids).covered
    end

    private

    def deck_member_ids(ids)
      return Set.new if deck_ids.empty?

      CollectionItem
        .where(collection_id: deck_ids, lexeme_id: ids)
        .distinct
        .pluck(:lexeme_id)
        .to_set
    end

    def studied_ids(ids)
      LexemeMemory
        .active
        .owned_by(@user)
        .where(lexeme_id: ids)
        .where
        .not(state: :unseen)
        .distinct
        .pluck(:lexeme_id)
        .to_set
    end

    def deck_ids
      @deck_ids ||= begin
        scope = Collection.desks_for(@user)
        scope = scope.where.not(id: @except) if @except
        scope.pluck(:id)
      end
    end
  end
end
