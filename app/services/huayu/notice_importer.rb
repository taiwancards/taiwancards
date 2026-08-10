# frozen_string_literal: true

module Huayu
  class NoticeImporter
    SOURCE = "community_notices"

    Result = Data.define(:imported, :updated, :retired) do
      def to_s = "notice sentences: #{imported} added, #{updated} updated, #{retired} retired"
    end

    def initialize(io: nil)
      @io = io
    end

    def call
      source = ContentSource.find_by(slug: SOURCE)
      return Result.new(imported: 0, updated: 0, retired: 0) if source.nil?

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
          "notice" => true,
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

      Result.new(imported:, updated:, retired: retire(kept)).tap { |result| @io&.puts(result.to_s) }
    end

    def drift?
      return false if ContentSource.find_by(slug: SOURCE).nil?

      stored.pluck(:text).to_set != wanted.keys.to_set
    end

    private

    def wanted
      @wanted ||= TaiwanNotices.all.each_with_object({}) do |notice, all|
        notice.items.each do |item|
          all[item.zh] = {"en" => item.names["en"], "ru" => item.names["ru"]}.compact_blank
        end
      end
    end

    def attach(lexeme, source)
      LexemeContentSource.insert_all(
        [{lexeme_id: lexeme.id, content_source_id: source.id, created_at: Time.current}],
        unique_by: %i[lexeme_id content_source_id]
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def stored
      Lexeme.where(kind: :sentence).where("lexemes.data ->> 'notice' IS NOT NULL")
    end

    def retire(kept)
      stored.where.not(id: kept).destroy_all.size
    end
  end
end
