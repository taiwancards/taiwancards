# frozen_string_literal: true

module Lexemes
  class Search
    LIMIT = 10
    CANDIDATES = 80
    KINDS = %w[character word collocation radical measure_word].freeze

    EXACT = 0
    TONED = 1
    PARTIAL = 2
    PLAIN = 3
    PREFIX = 4
    MEANING = 5
    FUZZY = 6

    Result = Data.define(:lexeme, :tier)

    Page = Data.define(:results, :truncated) do
      def any? = results.any?

      def empty? = results.empty?

      def each(&) = results.each(&)

      include Enumerable
    end

    def call(query, limit: LIMIT, kinds: KINDS)
      parsed = Huayu::ReadingQuery.call(query)
      return Page.new(results: [], truncated: false) if parsed.raw.blank?

      @kinds = kinds
      @depth = [(limit / LIMIT.to_f).ceil, 1].max
      rows = candidates(parsed)
      return Page.new(results: [], truncated: false) if rows.empty?

      ranked = ranked(rows, parsed)
      Page.new(results: ranked.first(limit), truncated: ranked.length > limit)
    end

    def tier_for(lexeme, parsed)
      return EXACT if lexeme.text == parsed.raw

      forms = forms_for(lexeme)
      if parsed.reading?
        return TONED if parsed.tones_given? && forms.intersect?(parsed.toned_tokens.to_set)

        if forms.intersect?(parsed.plain_tokens.to_set)
          return parsed.tones_partial? && tones_agree?(lexeme, parsed) ? PARTIAL : PLAIN
        end
      end

      return PREFIX if parsed.han? && lexeme.text.start_with?(parsed.raw)
      return MEANING if meaning_hit?(lexeme, parsed)
      return FUZZY if parsed.han?

      nil
    end

    private

    def kinds
      @kinds ||= KINDS
    end

    def depth
      @depth ||= 1
    end

    def candidates(parsed)
      branches = build_branches(parsed)
      return [] if branches.empty?

      Lexeme.find_by_sql(branches.join("\nUNION ALL\n")).uniq(&:id)
    end

    def build_branches(parsed)
      branches = [branch("lexemes.text = :raw", "lexemes.score NULLS LAST", 5, parsed)]

      tokens = parsed.tokens
      if tokens.any?
        branches <<
          branch(
            "lexemes.search_text IS NOT NULL AND string_to_array(lexemes.search_text, ' ') && ARRAY[:tokens]::text[]",
            "lexemes.score NULLS LAST",
            40 * depth,
            parsed
          )
      end

      if parsed.han?
        branches << branch("lexemes.text LIKE :prefix", "lexemes.score NULLS LAST", 20 * depth, parsed)
        branches << branch("lexemes.text % :raw", "similarity(lexemes.text, :raw) DESC", 10 * depth, parsed)
      elsif parsed.lower.length >= 2
        branches << branch("lexemes.search_text ILIKE :contains", "lexemes.score NULLS LAST", 25 * depth, parsed)
      end

      branches
    end

    def branch(condition, order, limit, parsed)
      ActiveRecord::Base.sanitize_sql_array(
        [
          "(SELECT lexemes.* FROM lexemes WHERE lexemes.kind IN (:kinds) " \
            "AND (:include_restricted OR lexemes.restricted = FALSE) AND (#{condition}) " \
            "ORDER BY #{order} LIMIT #{limit.to_i})",
          bindings(parsed)
        ]
      )
    end

    def bindings(parsed)
      {
        kinds: Lexeme.kinds.values_at(*kinds),
        include_restricted: Current.user&.restricted_access? || false,
        raw: parsed.raw,
        prefix: "#{parsed.raw}%",
        contains: "%#{parsed.lower}%",
        tokens: parsed.tokens.map { |token| Huayu::ReadingForms.reading_token(token) }.presence || [""]
      }
    end

    def ranked(rows, parsed)
      scored = rows.map { |lexeme| [tier_for(lexeme, parsed), lexeme] }
      scored
        .reject { |tier, _| tier.nil? }
        .sort_by { |tier, lexeme|
          [tier, lexeme.score || Float::INFINITY, lexeme.text.length, kind_rank(lexeme), lexeme.text]
        }
        .map { |tier, lexeme| Result.new(lexeme: lexeme, tier: tier) }
    end

    def kind_rank(lexeme)
      Lexeme.kinds.fetch(lexeme.kind.to_s, 9)
    end

    def forms_for(lexeme)
      @forms ||= {}
      @forms[lexeme.id] ||= lexeme
        .reading_set
        .flat_map { |reading| Huayu::ReadingForms.reading_terms(reading["pinyin"], reading["zhuyin"]) }
        .compact_blank
        .to_set
    end

    def numbered_forms(lexeme)
      @numbered ||= {}
      @numbered[lexeme.id] ||= lexeme
        .reading_set
        .filter_map { |reading| Huayu::ReadingForms.numbered_pinyin(reading["pinyin"]).presence }
    end

    def tones_agree?(lexeme, parsed)
      spec = parsed.tones
      numbered_forms(lexeme).any? do |numbered|
        parts = numbered.scan(/([a-z]+)(\d)/)
        next false unless parts.length == spec.length

        parts.each_with_index.all? { |(_, tone), position| spec[position].nil? || spec[position] == tone.to_i }
      end
    end

    def meaning_hit?(lexeme, parsed)
      return false if parsed.lower.length < 2

      lexeme.meanings.values.any? { |meaning| Array(meaning).join(" ").downcase.include?(parsed.lower) }
    end
  end
end
