# frozen_string_literal: true

module Phrases
  class Lexicon
    KINDS = %i[word collocation character].freeze

    Result = Data.define(:entries, :terms) do
      def for(pattern) = Array(terms[pattern.id]).filter_map { |text| entries[text] }
    end

    def initialize(patterns, analyzer: Huayu::TextAnalyzer.new)
      @patterns = Array(patterns)
      @analyzer = analyzer
    end

    def call
      terms = @patterns.to_h { |pattern| [pattern.id, candidates_for(pattern)] }
      Result.new(entries: resolve(terms.values.flatten.uniq), terms:)
    end

    private

    def candidates_for(pattern)
      (pattern.links + @analyzer.segment(pattern.literal)).uniq
    end

    def resolve(texts)
      return {} if texts.empty?

      Lexeme.visible.where(kind: KINDS, text: texts).index_by(&:text)
    end
  end
end
