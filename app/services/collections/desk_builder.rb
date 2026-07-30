# frozen_string_literal: true

module Collections
  class DeskBuilder
    def initialize(user: Current.user)
      @user = user
    end

    def call(text: nil, lexemes: nil, name: nil, facets: nil)
      lexemes = Array(lexemes.presence || lexemes_from_text(text)).compact.uniq
      collection = Collection.create!(
        user: @user,
        kind: :manual,
        name: name.presence || next_random_name,
        settings: settings_for(facets),
        last_used_at: Time.current
      )
      lexemes.each { |lexeme| collection.add_lexeme(lexeme) }
      lexemes.each { |lexeme| Lexemes::Activator.new.call(lexeme) }
      collection
    end

    def lexemes_from_text(text)
      return [] if text.blank?

      Huayu::TextAnalyzer.new(locale: I18n.locale).analyze(text).filter_map(&:lexeme)
    end

    private

    def settings_for(facets)
      chosen = Array(facets).map(&:to_s) & LexemeMemory.facets.keys
      return {} if chosen.empty?

      {"facets" => chosen}
    end

    def next_random_name
      taken = Collection.desks_for(@user).pluck(:name)
      next_n = taken.filter_map { |name| name[/\ARandom #(\d+)\z/, 1]&.to_i }.max.to_i + 1
      "Random ##{next_n}"
    end
  end
end
