# frozen_string_literal: true

module Collections
  class ListResolver
    HAN_RUN = /\p{Han}+/
    SEGMENT_LIMIT = 200

    Result = Data.define(:lexemes, :missing, :duplicates, :requested) do
      def empty?
        lexemes.empty?
      end
    end

    KIND_ORDER = {"word" => 0, "collocation" => 1, "character" => 2, "radical" => 3}.freeze

    def call(text)
      tokens = tokenize(text)
      return Result.new(lexemes: [], missing: [], duplicates: 0, requested: 0) if tokens.empty?

      exact = exact_index(tokens)
      lexemes = []
      seen = Set.new
      missing = []
      duplicates = 0
      segmented = 0

      tokens.each do |token|
        found = Array(exact[token])
        if found.empty? && token.length > 1 && segmented < SEGMENT_LIMIT
          segmented += 1
          found = segment(token)
        end

        if found.empty?
          missing << token unless missing.include?(token)
          next
        end

        found.each do |lexeme|
          seen.add?(lexeme.id) ? lexemes << lexeme : duplicates += 1
        end
      end

      Result.new(lexemes: ordered(lexemes), missing:, duplicates:, requested: tokens.length)
    end

    private

    def tokenize(text)
      text.to_s.scan(HAN_RUN)
    end

    def exact_index(tokens)
      index = {}
      tokens.uniq.each_slice(500) do |slice|
        Lexeme.permitted.where(text: slice).each do |lexeme|
          current = index[lexeme.text]
          index[lexeme.text] = [lexeme] if current.nil? || better?(lexeme, current.first)
        end
      end

      index
    end

    def better?(candidate, current)
      rank(candidate) < rank(current)
    end

    def rank(lexeme)
      base = KIND_ORDER.fetch(lexeme.kind.to_s, 9)
      lexeme.text.length == 1 && lexeme.character? ? -1 : base
    end

    def segment(token)
      Huayu::TextAnalyzer.new(locale: I18n.locale).analyze(token).filter_map(&:lexeme)
    rescue StandardError
      []
    end

    def ordered(lexemes)
      lexemes.sort_by { |lexeme| [lexeme.score || Float::INFINITY, lexeme.text] }
    end
  end
end
