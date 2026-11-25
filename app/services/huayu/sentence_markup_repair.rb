# frozen_string_literal: true

module Huayu
  class SentenceMarkupRepair
    PREFIX = /\Acontent(?=[^A-Za-z])/
    JOINER = /(?<=[。！？])[;；]/
    SQL = "^content[^A-Za-z]|[。！？][;；]"

    Result = Data.define(:cleaned, :merged) do
      def changed? = cleaned.positive? || merged.positive?

      def to_s = "sentence markup: #{cleaned} cleaned, #{merged} merged into an existing sentence"
    end

    def self.clean(text) = text.to_s.sub(PREFIX, "").gsub(JOINER, "")

    def initialize(io: nil)
      @io = io
    end

    def drift? = damaged.any?

    def call
      rewrites = {}
      merged = 0
      taken = existing

      damaged.each do |id, text|
        cleaned = self.class.clean(text)
        keeper_id = taken[cleaned]

        if keeper_id
          merge(keeper_id, id)
          merged += 1
        else
          taken[cleaned] = id
          rewrites[id] = cleaned
        end
      end

      SentenceRewrite.new.call(rewrites)
      result = Result.new(cleaned: rewrites.size, merged:)
      @io&.puts(result.to_s)
      result
    end

    private

    def damaged
      @damaged ||= Lexeme.where(kind: :sentence).where("text ~ ?", SQL).order(:id).pluck(:id, :text)
    end

    def existing
      cleaned = damaged.map { |_, text| self.class.clean(text) }
      Lexeme.where(kind: :sentence, text: cleaned).pluck(:text, :id).to_h
    end

    def merge(keeper_id, loser_id)
      keeper = Lexeme.find(keeper_id)
      Lexemes::KindMerge.new.absorb(keeper, Lexeme.find(loser_id))
      keeper.save! if keeper.changed?
      SentenceRewrite.new.call(keeper.id => keeper.text)
    end
  end
end
