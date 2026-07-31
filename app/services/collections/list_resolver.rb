# frozen_string_literal: true

module Collections
  class ListResolver
    HAN_RUN = /\p{Han}+/
    MAX_CHARS = 30_000
    LOOKUP_BATCH = 1_000

    Result = Data.define(:lexemes, :missing, :duplicates, :requested, :truncated) do
      def empty?
        lexemes.empty?
      end
    end

    KIND_ORDER = {"word" => 0, "collocation" => 1, "character" => 2, "radical" => 3}.freeze

    def initialize(analyzer: nil)
      @analyzer = analyzer
    end

    def call(text)
      raw = text.to_s
      truncated = raw.length > MAX_CHARS
      tokens = tokenize(truncated ? raw[0, MAX_CHARS] : raw)
      return Result.new(lexemes: [], missing: [], duplicates: 0, requested: 0, truncated:) if tokens.empty?

      exact = exact_index(tokens)
      segmented = segment_index(tokens.reject { |token| exact.key?(token) || token.length == 1 })
      collect(tokens, exact, segmented, truncated)
    end

    private

    def collect(tokens, exact, segmented, truncated)
      lexemes = []
      seen = Set.new
      missing = []
      duplicates = 0

      tokens.each do |token|
        found = exact[token] || segmented[token] || []
        if found.empty?
          missing << token unless missing.include?(token)
          next
        end

        found.each { |lexeme| seen.add?(lexeme.id) ? lexemes << lexeme : duplicates += 1 }
      end

      Result.new(lexemes: ordered(lexemes), missing:, duplicates:, requested: tokens.length, truncated:)
    end

    def tokenize(text)
      text.scan(HAN_RUN)
    end

    def exact_index(tokens)
      index = {}
      tokens.uniq.each_slice(LOOKUP_BATCH) do |slice|
        Lexeme.permitted.where(text: slice).each do |lexeme|
          current = index[lexeme.text]
          index[lexeme.text] = [lexeme] if current.nil? || better?(lexeme, current.first)
        end
      end

      index
    end

    def segment_index(tokens)
      unresolved = tokens.uniq
      return {} if unresolved.empty?

      unresolved.zip(analyzer.analyze_lines(unresolved)).to_h do |token, parsed|
        [token, parsed.filter_map(&:lexeme)]
      end

    rescue StandardError
      {}
    end

    def analyzer
      @analyzer ||= Huayu::TextAnalyzer.new(locale: I18n.locale)
    end

    def better?(candidate, current)
      rank(candidate) < rank(current)
    end

    def rank(lexeme)
      base = KIND_ORDER.fetch(lexeme.kind.to_s, 9)
      lexeme.text.length == 1 && lexeme.character? ? -1 : base
    end

    def ordered(lexemes)
      lexemes.sort_by { |lexeme| [lexeme.score || Float::INFINITY, lexeme.text] }
    end
  end
end
