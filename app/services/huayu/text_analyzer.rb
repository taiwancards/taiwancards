# frozen_string_literal: true

module Huayu
  class TextAnalyzer
    HAN = /\p{Han}/
    MAX_WORD = 8

    Token = Data.define(:kind, :text, :lexeme, :chars)

    class << self
      def vocabulary
        @vocabulary ||= {}
        @vocabulary[:zh_tw] ||= begin
          words = Lexeme.where(kind: %i[word collocation]).where("length(text) >= 2").pluck(:text).to_set
          words |= SegmentationVocabulary.words
          {words: words, max: [words.map(&:length).max || 2, MAX_WORD].min}
        end
      end

      def reset_vocabulary!
        @vocabulary = nil
      end
    end

    def initialize(locale: I18n.locale)
      @locale = locale
    end

    def analyze(text)
      text = text.to_s.strip
      return [] if text.blank?

      words = known_words
      tokens = tokenize(text, words)
      resolve(tokens)
    end

    def segment(text, excluding: nil)
      text = text.to_s.strip
      return [] if text.blank?

      words = known_words
      words = words - [excluding] if excluding && words.include?(excluding)

      tokenize(text, words).reject { |kind, _| kind == :literal }.map(&:last)
    end

    private

    def known_words
      @known_words ||= begin
        cached = self.class.vocabulary
        @max = cached[:max]
        cached[:words]
      end
    end

    def tokenize(text, words)
      result = []
      run = +""
      literal = +""

      flush_run = lambda do
        next if run.empty?

        segment_run(run.chars, words).each do |piece|
          result << [piece.length > 1 ? :word : :char, piece]
        end

        run = +""
      end

      text.each_char do |char|
        if char.match?(HAN)
          unless literal.empty?
            result << [:literal, literal]
            literal = +""
          end

          run << char
        else
          flush_run.call
          literal << char
        end
      end

      flush_run.call
      result << [:literal, literal] unless literal.empty?
      result
    end

    def segment_run(chars, words)
      bigrams = BigramFrequency.instance
      return segment_run_unigram(chars, words) unless bigrams.available?

      length = chars.length
      best = Array.new(length + 1) { {} }
      best[0][BigramFrequency::START] = [0.0, nil, nil]

      (1..length).each do |stop|
        first = [1, stop - @max + 1].max
        (first..stop).each do |start|
          previous = best[start - 1]
          next if previous.empty?

          token = chars[start - 1, stop - start + 1].join
          next if token.length > 1 && !words.include?(token)

          previous.each do |context, (cost, _, _)|
            total = cost + bigrams.cost(context, token)
            current = best[stop][token]
            best[stop][token] = [total, start - 1, context] if current.nil? || total < current[0]
          end
        end
      end

      return [] if best[length].empty?

      token = best[length].min_by { |_, entry| entry[0] }.first
      pieces = []
      stop = length
      while stop.positive?
        _, start, context = best[stop][token]
        pieces.unshift(chars[start, stop - start].join)
        stop = start
        token = context
      end

      pieces
    end

    def segment_run_unigram(chars, words)
      length = chars.length
      best = Array.new(length + 1, Float::INFINITY)
      back = Array.new(length + 1, 0)
      best[0] = 0.0
      frequency = WordFrequency.instance

      (1..length).each do |stop|
        first = [1, stop - @max + 1].max
        (first..stop).each do |start|
          previous = best[start - 1]
          next if previous.infinite?

          token = chars[start - 1, stop - start + 1].join
          cost = if token.length == 1
            frequency.char_cost(token)
          elsif words.include?(token)
            frequency.word_cost(token)
          else
            next
          end

          total = previous + cost
          if total < best[stop]
            best[stop] = total
            back[stop] = start - 1
          end
        end
      end

      pieces = []
      stop = length
      while stop.positive?
        start = back[stop]
        pieces.unshift(chars[start, stop - start].join)
        stop = start
      end

      pieces
    end

    def resolve(tokens)
      han_texts = tokens.select { |kind, _| kind != :literal }.map(&:last).uniq
      lexemes = Lexeme.where(kind: %i[word character], text: han_texts).index_by(&:text)
      char_texts = han_texts.flat_map(&:chars).uniq
      chars = Lexeme.where(kind: :character, text: char_texts).index_by(&:text)

      tokens.map do |kind, text|
        next Token.new(kind: :literal, text:, lexeme: nil, chars: []) if kind == :literal

        lexeme = lexemes[text]
        components = text.chars.map { |char| chars[char] }.compact
        Token.new(kind:, text:, lexeme:, chars: components)
      end
    end
  end
end
