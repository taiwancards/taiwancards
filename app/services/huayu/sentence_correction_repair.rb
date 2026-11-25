# frozen_string_literal: true

module Huayu
  class SentenceCorrectionRepair
    Result = Data.define(:corrected, :merged) do
      def to_s = "sentence transcripts: #{corrected} corrected, #{merged} merged into an existing sentence"
    end

    def initialize(corrections: TranscriptCorrections.all, rejected: SentenceRejectStore.texts, io: nil)
      @corrections = corrections
      @rejected = rejected
      @io = io
    end

    def drift? = misspelt.any?

    def call
      taken = Lexeme.where(kind: :sentence, text: misspelt.map { |_, text| @corrections[text] }).pluck(:text, :id).to_h
      rewrites = {}
      merged = 0

      misspelt.each do |id, text|
        corrected = @corrections[text]
        keeper_id = taken[corrected]

        if keeper_id
          merge(keeper_id, id)
          merged += 1
        else
          taken[corrected] = id
          rewrites[id] = corrected
        end
      end

      SentenceRewrite.new.call(rewrites)
      result = Result.new(corrected: rewrites.size, merged:)
      @io&.puts(result.to_s)
      result
    end

    private

    def misspelt
      @misspelt ||= Lexeme
        .where(kind: :sentence, text: @corrections.keys)
        .order(:id)
        .pluck(:id, :text)
        .reject { |_, text| @rejected.include?(text) || @rejected.include?(@corrections[text]) }
    end

    def merge(keeper_id, loser_id)
      keeper = Lexeme.find(keeper_id)
      Lexemes::KindMerge.new.absorb(keeper, Lexeme.find(loser_id))
      keeper.save! if keeper.changed?
    end
  end
end
