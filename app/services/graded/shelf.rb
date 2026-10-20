# frozen_string_literal: true

module Graded
  class Shelf
    TIER_FOR_GRADE = {
      0 => "chars150",
      1 => "chars150",
      2 => "chars300",
      3 => "words500",
      4 => "words1000",
      5 => "words1500",
      6 => "words4808",
      7 => "words4808"
    }.freeze

    TierProgress = Data.define(:read, :total) do
      def started? = read.positive?

      def finished? = total.positive? && read == total
    end

    def initialize(user)
      @user = user
    end

    def read?(text) = completions.key?(text.id)

    def completion(text) = completions[text.id]

    def progress(tier_id)
      texts = Library.texts(tier_id)
      TierProgress.new(read: texts.count { |text| read?(text) }, total: texts.size)
    end

    def tier
      @tier ||= begin
        tiers = Library.tiers.filter_map { |id| Levels.find(id) }
        by_level = tiers.find { |entry| entry.id == TIER_FOR_GRADE.fetch(@user.level_grade.clamp(0, 7)) }
        by_memory = tiers.select { |entry| entry.size <= known_count(entry.kind) }.last
        [by_level, by_memory].compact.max_by { |entry| tiers.index(entry) } || tiers.first
      end
    end

    def next_text
      return nil if tier.nil?

      @next_text ||= begin
        ids = Library.tiers
        upcoming = ids.drop(ids.index(tier.id)).flat_map { |id| Library.texts(id) }
        upcoming.find { |text| !read?(text) }
      end
    end

    private

    def completions
      @completions ||= GradedCompletion.owned_by(@user).index_by(&:text_id)
    end

    def known_count(kind)
      known_counts[kind == "chars" ? "character" : "word"].to_i
    end

    def known_counts
      @known_counts ||= LexemeMemory
        .owned_by(@user)
        .state_review
        .where(facet: LexemeMemory.facets[:recognition])
        .joins(:lexeme)
        .where(lexemes: {kind: %i[word character]})
        .group("lexemes.kind")
        .count
        .transform_keys { |kind| Lexeme.kinds.key(kind) || kind.to_s }
    end
  end
end
