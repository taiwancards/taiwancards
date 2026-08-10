# frozen_string_literal: true

module Huayu
  class RestrictedFlagger
    RESTRICTED_PREFIXES = ["Textbook"].freeze
    OPEN_PREFIXES = ["TOCFL ", "TBCL ", "Kangxi", "MOE "].freeze

    def call
      Lexeme.connection.exec_update(
        "UPDATE lexemes SET restricted = #{verdict} WHERE #{candidates} AND restricted IS DISTINCT FROM #{verdict}"
      )
    end

    def drift?
      scope = Lexeme.all
      return true if scope.where.not(kind: :phrase).where(restricted: true).exists?

      scope
        .where(kind: :phrase, restricted: false)
        .where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE #{like_any(RESTRICTED_PREFIXES)})")
        .where("NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE #{like_any(OPEN_PREFIXES)})")
        .exists?
    end

    private

    def candidates = "(restricted OR kind = #{Lexeme.kinds.fetch("phrase")})"

    def verdict
      @verdict ||= <<~SQL.squish
        (kind = #{Lexeme.kinds.fetch("phrase")}
          AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE #{like_any(RESTRICTED_PREFIXES)})
          AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(sources) s WHERE #{like_any(OPEN_PREFIXES)}))
      SQL
    end

    def like_any(prefixes)
      prefixes.map { |p| "s LIKE #{Lexeme.connection.quote("#{p}%")}" }.join(" OR ")
    end
  end
end
