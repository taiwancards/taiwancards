# frozen_string_literal: true

module Huayu
  class TypedQuery
    class << self
      def normalize(text)
        typed = text.to_s.strip
        rewritable = rewritable(typed)
        return typed if rewritable.empty?

        TraditionalOnly.to_traditional(typed, keep: typed.each_char.to_set - rewritable)
      end

      private

      def rewritable(text)
        text
          .each_char
          .select { |char| TraditionalOnly.simplified?(char) }
          .uniq
          .reject { |char| spelled?(char) }
          .to_set
      end

      def spelled?(char)
        Lexeme
          .where(kind: Lexeme::DICTIONARY_KINDS)
          .where("length(text) > 1")
          .where("text LIKE ?", "%#{Lexeme.sanitize_sql_like(char)}%")
          .exists?
      end
    end
  end
end
