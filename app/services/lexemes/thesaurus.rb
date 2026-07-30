# frozen_string_literal: true

module Lexemes
  class Thesaurus
    GROUPS = %w[synonyms antonyms related collocates].freeze
    LEXICAL = %w[synonyms antonyms].freeze
    DISTRIBUTIONAL = %w[related collocates].freeze
    KINDS = %i[word collocation character].freeze
    KIND_ORDER = {"word" => 0, "collocation" => 1, "character" => 2}.freeze
    LIMIT = 12
    MIN_ADJUSTED_PER_MILLION = 4.0

    Result = Data.define(:groups, :evidence) do
      def any? = groups.any? { |_name, entries| entries.any? }

      def distributional? = DISTRIBUTIONAL.any? { |group| groups[group].present? }
    end

    EMPTY = Result.new(groups: GROUPS.index_with { [] }, evidence: 0)

    def initialize(frequency: Huayu::WordFrequency)
      @frequency = frequency
    end

    def call(lexeme)
      evidence = @frequency.adjusted(lexeme.text)
      names = evidence >= MIN_ADJUSTED_PER_MILLION ? GROUPS : LEXICAL
      wanted = names.to_h { |group| [group, Array(lexeme.data[group])] }
      texts = wanted.values.flatten.uniq
      return EMPTY if texts.empty?

      found = resolve(texts)
      groups = GROUPS.to_h do |group|
        entries = Array(wanted[group]).filter_map { |word| found[word] }
        entries = entries.sort_by { |entry| entry.score || Float::INFINITY } if LEXICAL.include?(group)
        [group, entries.first(LIMIT)]
      end

      Result.new(groups:, evidence:)
    end

    private

    def resolve(texts)
      Lexeme
        .visible
        .where(kind: KINDS, text: texts)
        .to_a
        .group_by(&:text)
        .transform_values { |rows| rows.min_by { |row| KIND_ORDER.fetch(row.kind.to_s, 9) } }
    end
  end
end
