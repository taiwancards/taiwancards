# frozen_string_literal: true

module Lexemes
  class SentenceCase
    LOCALES = %w[en ru].freeze
    LOWER = "^[[:lower:]]"

    Result = Data.define(:fixed)

    def initialize(io: $stdout)
      @io = io
    end

    def call
      fixed = LOCALES.sum { |locale| capitalise(locale) }
      @io.puts("sentence translations capitalised: #{fixed}")
      Result.new(fixed:)
    end

    def drift?
      LOCALES.any? { |locale| scope(locale).exists? }
    end

    private

    def scope(locale)
      Lexeme.where(kind: :sentence).where("meanings ->> :locale ~ :lower", locale:, lower: LOWER)
    end

    def capitalise(locale)
      Lexeme.connection.update(
        Lexeme.sanitize_sql_array(
          [
            "UPDATE lexemes SET meanings = jsonb_set(meanings, ARRAY[:locale], " \
              "to_jsonb(upper(left(meanings ->> :locale, 1)) || substr(meanings ->> :locale, 2))), " \
              "updated_at = now() " \
              "WHERE kind = :kind AND meanings ->> :locale ~ :lower",
            {locale:, kind: Lexeme.kinds[:sentence], lower: LOWER}
          ]
        )
      )
    end
  end
end
