# frozen_string_literal: true

module Huayu
  class RestrictedFlagger
    RESTRICTED_PREFIXES = ["Textbook"].freeze
    OPEN_PREFIXES = ["TOCFL ", "TBCL ", "Kangxi", "MOE "].freeze

    VERDICT = <<~SQL
      (kind = :phrase
        AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE s LIKE ANY (ARRAY[:closed]))
        AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE s LIKE ANY (ARRAY[:open])))
    SQL
      .squish

    UPDATE = <<~SQL
      UPDATE lexemes SET restricted = #{VERDICT}
      WHERE (restricted OR kind = :phrase) AND restricted IS DISTINCT FROM #{VERDICT}
    SQL
      .squish

    def call
      Lexeme.connection.exec_update(Lexeme.sanitize_sql_array([UPDATE, values]))
    end

    def drift?
      scope = Lexeme.all
      return true if scope.where.not(kind: :phrase).where(restricted: true).exists?

      scope
        .where(kind: :phrase, restricted: false)
        .where(
          "EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE s LIKE ANY (ARRAY[?]))",
          patterns(RESTRICTED_PREFIXES)
        )
        .where(
          "NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE s LIKE ANY (ARRAY[?]))",
          patterns(OPEN_PREFIXES)
        )
        .exists?
    end

    private

    def values
      {
        phrase: Lexeme.kinds.fetch("phrase"),
        closed: patterns(RESTRICTED_PREFIXES),
        open: patterns(OPEN_PREFIXES)
      }
    end

    def patterns(prefixes) = prefixes.map { |prefix| "#{prefix}%" }
  end
end
