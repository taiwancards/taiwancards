# frozen_string_literal: true

module Huayu
  class SentenceSegments
    Run = Data.define(:text, :lexeme)

    class << self
      def runs_for(sentences)
        sentences = sentences.compact.uniq
        return {} if sentences.empty?

        segments = sentences.flat_map { |sentence| Array(sentence.data["segments"]) }.uniq
        words = Lexeme.where(kind: :word, text: segments).index_by(&:text)
        singles = segments.select { |segment| segment.length == 1 } - words.keys
        characters = Lexeme.where(kind: :character, text: singles).index_by(&:text)

        sentences.index_with { |sentence| walk(sentence, words, characters) }
      end

      private

      def walk(sentence, words, characters)
        text = sentence.text
        segments = Array(sentence.data["segments"])
        runs = []
        position = 0
        index = 0

        while position < text.length
          segment = segments[index]
          if segment && text[position, segment.length] == segment
            runs << Run.new(text: segment, lexeme: words[segment] || characters[segment])
            position += segment.length
            index += 1
          else
            runs << Run.new(text: text[position], lexeme: nil)
            position += 1
          end
        end

        runs
      end
    end
  end
end
