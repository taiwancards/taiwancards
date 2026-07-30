# frozen_string_literal: true

module Huayu
  class ExampleLinker
    def initialize(io: $stdout)
      @io = io
    end

    def call
      sentences = Lexeme
        .where(kind: :sentence)
        .pluck(:text, :id)
        .to_h

      linked = 0
      missing = 0

      SenseExample.where(kind: :sentence).find_in_batches(batch_size: 1000) do |batch|
        updates = batch.filter_map do |example|
          id = sentences[normalize(example.text)]
          next (missing += 1) && nil if id.nil?
          next if example.lexeme_id == id

          [example.id, id]
        end

        next if updates.empty?

        updates.each { |example_id, lexeme_id| SenseExample.where(id: example_id).update_all(lexeme_id: lexeme_id) }
        linked += updates.length
      end

      @io.puts(format("examples linked to sentences: %6d", linked))
      @io.puts(format("examples without a sentence : %6d", missing))
      linked
    end

    private

    def normalize(text)
      text.to_s.strip.gsub(/[[:space:]]+/, "")
    end
  end
end
