# frozen_string_literal: true

module Huayu
  class SentenceRewrite
    BATCH = 200

    def initialize(analyzer: TextAnalyzer.new, difficulty: SentenceDifficulty.new)
      @analyzer = analyzer
      @difficulty = difficulty
    end

    def call(replacements)
      replacements.each_slice(BATCH) do |slice|
        texts = slice.to_h

        Lexeme.where(id: texts.keys).each do |lexeme|
          text = texts[lexeme.id]
          next if text.blank?

          tokens = @analyzer.segment(text)
          lexeme.text = text
          lexeme.data = lexeme.data.merge(
            "length" => text.scan(/\p{Han}/).length,
            "segments" => tokens,
            "difficulty" => @difficulty.call(text, tokens: tokens)
          )
          lexeme.save!
        end
      end
    end
  end
end
