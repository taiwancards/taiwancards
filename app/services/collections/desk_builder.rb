# frozen_string_literal: true

module Collections
  class DeskBuilder
    RANDOM_NAME = /\ARandom #(\d+)\z/
    NAME_RETRIES = 3

    def initialize(user: Current.user)
      @user = user
    end

    def call(text: nil, lexemes: nil, lexeme_ids: nil, name: nil, facets: nil)
      ids = resolve_ids(lexeme_ids, lexemes, text)
      collection = create_collection(name, facets)
      collection.add_lexemes(ids)
      collection
    end

    def lexemes_from_text(text)
      return [] if text.blank?

      Huayu::TextAnalyzer.new(locale: I18n.locale).analyze(text).filter_map(&:lexeme)
    end

    private

    def resolve_ids(lexeme_ids, lexemes, text)
      return Array(lexeme_ids).map(&:to_i).reject(&:zero?).uniq if lexeme_ids.present?

      Array(lexemes.presence || lexemes_from_text(text)).compact.map(&:id).uniq
    end

    def create_collection(name, facets)
      wanted = name.presence&.strip&.first(200)
      attempt = 0
      begin
        Collection.create!(
          user: @user,
          kind: :manual,
          name: suffixed(wanted, attempt),
          settings: settings_for(facets),
          last_used_at: Time.current
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        attempt += 1
        raise if attempt > NAME_RETRIES

        retry
      end
    end

    def suffixed(wanted, attempt)
      return next_random_name if wanted.blank?
      return wanted if attempt.zero?

      "#{wanted.first(190)} (#{attempt + 1})"
    end

    def settings_for(facets)
      chosen = Array(facets).map(&:to_s) & LexemeMemory.facets.keys
      return {} if chosen.empty?

      {"facets" => chosen}
    end

    def next_random_name
      taken = Collection
        .desks_for(@user)
        .where("name ~ '^Random #[0-9]+$'")
        .pluck(:name)
        .filter_map { |name| name[RANDOM_NAME, 1]&.to_i }
      "Random ##{taken.max.to_i + 1}"
    end
  end
end
