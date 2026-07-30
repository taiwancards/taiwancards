# frozen_string_literal: true

module Lexemes
  class DetailDefault
    FULL = "full"
    BRIEF = "brief"
    NOVICE_TAGS = %w[Novice1 Novice2].freeze
    BEYOND_NOVICE_GRADE = 3
    READY_SHARE = 2.0 / 3

    def initialize(user)
      @user = user
    end

    def call
      return FULL if @user.nil?
      return FULL if @user.level_grade >= BEYOND_NOVICE_GRADE

      Rails.cache.fetch(cache_key, expires_in: 1.hour) { novice_ready? ? FULL : BRIEF }
    end

    private

    def cache_key
      "dict_detail_default/#{@user.id}"
    end

    def novice_ready?
      collections = Collection.where(kind: :tocfl, level_tag: NOVICE_TAGS)
      total = collections.sum(:items_count)
      return false if total.zero?

      ids = CollectionItem.where(collection: collections).select(:lexeme_id)
      known = LexemeMemory.owned_by(@user).state_review.where(lexeme_id: ids).distinct.count(:lexeme_id)
      known >= total * READY_SHARE
    end
  end
end
