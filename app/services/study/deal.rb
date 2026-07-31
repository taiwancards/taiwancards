# frozen_string_literal: true

module Study
  class Deal
    COMPONENT_FACETS = %w[recognition reading writing].freeze
    COMPONENT_CAP = 200
    NO_GRADE = 9
    FREQ_BUCKET = 500
    NO_FREQ = 200

    def initialize(user: Current.user, facets: CardSet::SWIPE_FACETS)
      @user = user
      @facets = Array(facets) & LexemeMemory.facets.keys
    end

    def call(lexeme_ids)
      ids = Array(lexeme_ids).uniq
      return [] if ids.empty? || @facets.empty?

      primary = Lexeme.where(id: ids).to_a
      derived = components_for(primary, ids)
      familiarity = familiarity_for(primary + derived)

      cards(primary, familiarity, derived: false) + cards(derived, familiarity, derived: true)
    end

    private

    def cards(lexemes, familiarity, derived:)
      allowed = derived ? @facets & COMPONENT_FACETS : @facets

      lexemes.flat_map do |lexeme|
        difficulty = difficulty_of(lexeme)
        (Lexemes::Facets.for(lexeme) & allowed).map do |facet|
          Ordering::Card.new(
            lexeme_id: lexeme.id,
            facet:,
            difficulty:,
            familiarity: familiarity[[lexeme.id, facet]].to_f,
            derived:
          )
        end
      end
    end

    def components_for(primary, ids)
      return [] if (@facets & COMPONENT_FACETS).empty?

      parents = primary.reject(&:character?).map(&:id)
      return [] if parents.empty?

      Lexeme
        .joins(:parent_links)
        .where(lexeme_links: {parent_id: parents}, kind: :character)
        .where
        .not(id: ids)
        .distinct
        .limit(COMPONENT_CAP)
        .to_a
    end

    def familiarity_for(lexemes)
      ids = lexemes.map(&:id)
      return {} if ids.empty?

      LexemeMemory
        .owned_by(@user)
        .where(lexeme_id: ids)
        .pluck(:lexeme_id, :facet, :stability, :state)
        .to_h { |lexeme_id, facet, stability, state| [[lexeme_id, facet], strength(stability, state)] }
    end

    def strength(stability, state)
      return 0.0 if state == LexemeMemory.states[:unseen]

      stability.to_f.clamp(0.0, 365.0)
    end

    def difficulty_of(lexeme)
      [
        lexeme.level_index || NO_GRADE,
        Ordering::KIND_WEIGHT.fetch(lexeme.kind.to_s, 3),
        (lexeme.freq_rank ? lexeme.freq_rank / FREQ_BUCKET : NO_FREQ),
        lexeme.text.length
      ]
    end
  end
end
