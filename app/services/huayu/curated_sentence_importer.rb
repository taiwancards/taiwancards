# frozen_string_literal: true

module Huayu
  class CuratedSentenceImporter
    Result = Data.define(:label, :imported, :updated, :retired) do
      def to_s = "#{label} sentences: #{imported} added, #{updated} updated, #{retired} retired"
    end

    def initialize(io: nil)
      @io = io
    end

    def call
      source = ContentSource.find_by(slug: self.class::SOURCE)
      return result(0, 0, 0) if source.nil?

      analyzer = TextAnalyzer.new
      difficulty = SentenceDifficulty.new
      imported = 0
      updated = 0
      kept = []

      wanted.each do |text, meanings|
        lexeme = Lexeme.find_by(kind: :sentence, text: text)
        fresh = lexeme.nil?
        lexeme ||= Lexeme.new(kind: :sentence, text: text)
        tokens = analyzer.segment(text)

        lexeme.meanings = lexeme.meanings.merge(meanings)
        lexeme.data = lexeme.data.merge(
          self.class::MARKER => true,
          "length" => text.scan(/\p{Han}/).length,
          "segments" => tokens,
          "difficulty" => difficulty.call(text, tokens: tokens)
        )
        lexeme.lexeme_content_sources.build(content_source: source) if fresh

        if lexeme.changed?
          lexeme.save!
          fresh ? imported += 1 : updated += 1
        end

        attach(lexeme, source) unless fresh
        kept << lexeme.id
      end

      result(imported, updated, retire(kept)).tap { |summary| @io&.puts(summary.to_s) }
    end

    def drift?
      return false if ContentSource.find_by(slug: self.class::SOURCE).nil?

      meanings = stored.pluck(:text, :meanings).to_h
      return true if meanings.keys.to_set != wanted.keys.to_set

      wanted.any? { |text, locales| meanings[text].slice(*locales.keys) != locales }
    end

    private

    def wanted = raise NotImplementedError

    def result(imported, updated, retired) = Result.new(label: self.class::MARKER, imported:, updated:, retired:)

    def attach(lexeme, source)
      LexemeContentSource.insert_all(
        [{lexeme_id: lexeme.id, content_source_id: source.id, created_at: Time.current}],
        unique_by: %i[lexeme_id content_source_id]
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def stored
      Lexeme.where(kind: :sentence).where("lexemes.data ->> ? IS NOT NULL", self.class::MARKER)
    end

    def retire(kept)
      stored.where.not(id: kept).destroy_all.size
    end
  end
end
