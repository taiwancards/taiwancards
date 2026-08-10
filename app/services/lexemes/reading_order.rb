# frozen_string_literal: true

module Lexemes
  class ReadingOrder
    Result = Data.define(:reordered)

    def initialize(io: $stdout)
      @io = io
    end

    def call
      reordered = misordered.each { |lexeme, order| rewrite(lexeme, order) }.size
      @io.puts("破音字 whose readings were put in order of use: #{reordered}")
      Result.new(reordered:)
    end

    def drift? = misordered.any?

    private

    def misordered
      @misordered ||= begin
        rank = Huayu::ReadingRank.new
        weights = rank.weights
        candidates.filter_map do |lexeme|
          order = rank.order(lexeme, weights[lexeme.id])
          [lexeme, order] unless order == lexeme.reading_set
        end
      end
    end

    def candidates
      Lexeme.where(kind: :character).where("jsonb_array_length(data -> 'readings') > 1")
    end

    def rewrite(lexeme, order)
      lexeme.update_columns(readings: order.first, data: lexeme.data.merge("readings" => order))
    end
  end
end
