# frozen_string_literal: true

module Huayu
  class SegmentationBlocks
    PATH = AppData.path("huayu/no_segment.json")
    FLAG = "no_segment"

    Result = Data.define(:blocked, :released)

    class << self
      def words
        @words ||= PATH.exist? ? Array(JSON.parse(PATH.read)["words"]).to_set : Set.new
      end

      def reset!
        @words = nil
      end
    end

    def initialize(words: self.class.words)
      @words = words.to_a
    end

    def call
      result = Result.new(blocked: block, released: release)
      TextAnalyzer.reset_vocabulary!
      result
    end

    private

    def block
      pending = Lexeme.where(kind: Lexeme::DICTIONARY_KINDS, text: @words).where.not("data ? '#{FLAG}'")
      pending.each { |lexeme| lexeme.update_column(:data, lexeme.data.merge(FLAG => true)) }.size
    end

    def release
      stale = Lexeme.where("data ? '#{FLAG}'")
      stale = stale.where.not(text: @words) if @words.any?
      stale.each { |lexeme| lexeme.update_column(:data, lexeme.data.except(FLAG)) }.size
    end
  end
end
