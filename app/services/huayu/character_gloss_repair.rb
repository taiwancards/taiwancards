# frozen_string_literal: true

module Huayu
  class CharacterGlossRepair
    LOCALES = %w[en ru].freeze
    HEADLINE_SENSES = 3
    MINIMUM_WORD = 3
    STOP = %w[to a an the of in on for and or with by as at is be one used].to_set.freeze
    REGISTER = /\A(?:literary|figurative|colloquial|книжн\.|перен\.|разг\.)\s*:\s*/i
    SENSES_DESCRIBE_ANOTHER_READING = %w[台 并 洒].freeze

    Result = Data.define(:examined, :texts) do
      def repaired = texts.length

      def changed? = texts.any?

      def to_s
        "character glosses rebuilt from senses: #{repaired} of #{examined} (#{texts.join(" ")})"
      end
    end

    def initialize(tainted: nil)
      @tainted = tainted
    end

    def call
      rows = pending
      rows.each { |lexeme, meanings| lexeme.update!(meanings: meanings) }
      Result.new(examined: candidates.length, texts: rows.map { |lexeme, _| lexeme.text })
    end

    def drift? = pending.any?

    private

    def tainted
      @tainted ||= GlossCollisions.tainted
    end

    def candidates
      @candidates ||= begin
        texts = tainted.keys - SENSES_DESCRIBE_ANOTHER_READING
        if texts.empty?
          []
        else
          Lexeme
            .where(kind: :character, text: texts)
            .includes(:senses)
            .select { |lexeme| lexeme.meanings["en"].to_s.strip == tainted[lexeme.text] }
        end
      end
    end

    def pending
      @pending ||= candidates.filter_map do |lexeme|
        replacement = rebuild(lexeme)
        next if replacement.nil?

        [lexeme, lexeme.meanings.merge(replacement)]
      end
    end

    def rebuild(lexeme)
      senses = lexeme.senses_for_main_reading
      return nil if senses.empty?
      return nil unless contradicted?(lexeme, senses)

      replacement = LOCALES.to_h { |locale| [locale, headline(senses, locale)] }.compact_blank
      return nil if replacement["en"].blank?

      replacement
    end

    def contradicted?(lexeme, senses)
      pool = significant(senses.filter_map { |sense| sense.meaning(:en) }.join(" "))
      own = significant(lexeme.meanings["en"])
      return false if pool.empty? || own.empty?

      own.intersection(pool).empty?
    end

    def significant(value)
      value
        .to_s
        .downcase
        .scan(/[a-z']+/)
        .reject { |word| STOP.include?(word) || word.length < MINIMUM_WORD }
        .to_set
    end

    def headline(senses, locale)
      senses
        .filter_map { |sense| summarise(sense.meaning(locale)) }
        .uniq
        .first(HEADLINE_SENSES)
        .join("; ")
    end

    def summarise(value)
      text = value.to_s.strip
      return nil if text.match?(REGISTER)

      text.split(":").first.to_s.strip.presence
    end
  end
end
