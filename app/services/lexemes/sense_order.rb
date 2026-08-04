# frozen_string_literal: true

module Lexemes
  class SenseOrder
    PARK = 10_000

    Result = Data.define(:reordered)

    def initialize(io: $stdout)
      @io = io
    end

    def call
      reordered = misordered.each { |lexeme, order| rewrite(lexeme, order) }.size
      @io.puts("lexemes whose senses were put in reading order: #{reordered}")
      Result.new(reordered:)
    end

    def drift? = misordered.any?

    def self.ordered(lexeme)
      readings = lexeme.reading_set.filter_map { |reading| reading["pinyin"].presence }
      return lexeme.senses.to_a if readings.size < 2

      lexeme.senses.sort_by.with_index do |sense, index|
        [readings.index(sense.reading) || readings.size, index]
      end
    end

    private

    def misordered
      @misordered ||= candidates.filter_map do |lexeme|
        order = self.class.ordered(lexeme)
        [lexeme, order] unless order == lexeme.senses.to_a
      end
    end

    def candidates
      Lexeme
        .where(kind: %i[word character])
        .where("jsonb_array_length(data->'readings') > 1")
        .where(id: LexemeSense.select(:lexeme_id))
        .includes(:senses)
    end

    def rewrite(lexeme, order)
      ActiveRecord::Base.transaction do
        LexemeSense.where(lexeme_id: lexeme.id).update_all("position = position + #{PARK}")
        order.each_with_index do |sense, position|
          LexemeSense.where(id: sense.id).update_all(position: position)
        end
      end
    end
  end
end
