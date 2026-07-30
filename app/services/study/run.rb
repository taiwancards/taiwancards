# frozen_string_literal: true

module Study
  class Run
    RADIX = 36
    REPEATED = [Fsrs::Scheduler::RATINGS[:again], Fsrs::Scheduler::RATINGS[:hard]].freeze
    PASSED = [Fsrs::Scheduler::RATINGS[:good], Fsrs::Scheduler::RATINGS[:easy]].freeze

    SITTING_CAP = 250
    WHOLE_COLLECTION = %w[collection redo].freeze

    class << self
      def start(mode:, size: nil, collection: nil, now: Time.current)
        picker = CardSet.new(now:)
        lexeme_ids = picker.select(mode:, size:, collection:).first(SITTING_CAP)
        whole = WHOLE_COLLECTION.include?(mode) && collection.present?

        new(
          "sid" => SecureRandom.uuid,
          "mode" => mode,
          "col" => whole ? collection.id : nil,
          "ids" => whole ? nil : pack(lexeme_ids),
          "facets" => picker.facets.join(","),
          "total" => picker.tokens(lexeme_ids).size
        )
          .compacted
      end

      def resume(state) = new(state)

      def pack(lexeme_ids) = lexeme_ids.map { |id| id.to_i.to_s(RADIX) }.join(",")

      def unpack(packed) = packed.to_s.split(",").map { |chunk| chunk.to_i(RADIX) }
    end

    def initialize(state)
      @state = state.to_h.stringify_keys
    end

    attr_reader :state

    def compacted
      @state = @state.compact
      self
    end

    def mode = @state["mode"].presence || "daily"

    def session_id = @state["sid"].presence

    def total = @state["total"].to_i

    def head = queue.first

    def remaining = queue.size

    def done = latest_ratings.count { |_token, rating| PASSED.include?(rating) }

    def again = ratings.count { |rating| REPEATED.include?(rating) }

    def queue
      @queue ||= pending + repeated
    end

    private

    def lexeme_ids
      @lexeme_ids ||= @state["col"].present? ? collection_lexeme_ids : self.class.unpack(@state["ids"])
    end

    def collection_lexeme_ids
      Collection
        .where(user_id: [nil, Current.user&.id])
        .find_by(id: @state["col"])
        &.lexemes
        &.limit(CardSet::COLLECTION_CAP)
        &.pluck(:id)
        .to_a
    end

    def facets = @facets ||= @state["facets"].to_s.split(",")

    def pending = all_tokens.reject { |token| latest_ratings.key?(token) }

    def repeated = latest_ratings.select { |_token, rating| REPEATED.include?(rating) }.keys

    def all_tokens
      @all_tokens ||= lexeme_ids.empty? ? [] : CardSet.new.tokens(lexeme_ids, facets:)
    end

    def rows
      @rows ||= if session_id.blank?
        []
      else
        LexemeReview
          .where(session_id: session_id)
          .order(:reviewed_at, :id)
          .pluck(:lexeme_id, :facet, :rating)
      end
    end

    def ratings = rows.map(&:last)

    def latest_ratings
      @latest_ratings ||= rows.each_with_object({}) do |(lexeme_id, facet, rating), acc|
        token = "#{lexeme_id}:#{facet}"
        acc.delete(token)
        acc[token] = rating
      end
    end
  end
end
