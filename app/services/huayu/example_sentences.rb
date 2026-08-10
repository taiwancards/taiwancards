# frozen_string_literal: true

module Huayu
  class ExampleSentences
    ORDER = "(coalesce(btrim(lexemes.meanings ->> ?), '') = '') ASC, " \
      "jsonb_exists(lexemes.data, 'audio') DESC, " \
      "sentence_profiles.difficulty ASC NULLS LAST, " \
      "sentence_words.gdex DESC, " \
      "lexemes.id ASC"

    class << self
      def for(lexeme, limit:, locale: I18n.locale)
        Lexeme
          .where(kind: :sentence)
          .visible
          .joins("JOIN sentence_words ON sentence_words.sentence_id = lexemes.id")
          .where(sentence_words: {lexeme_id: lexeme.id})
          .left_joins(:sentence_profile)
          .preload(:content_sources, :sentence_profile)
          .order(Arel.sql(Lexeme.sanitize_sql_array([ORDER, locale.to_s])))
          .limit(limit)
          .to_a
      end
    end
  end
end
