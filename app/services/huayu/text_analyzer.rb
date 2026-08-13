# frozen_string_literal: true

module Huayu
  class TextAnalyzer
    HAN = /\p{Han}/
    ALNUM = /[A-Za-z0-9]/
    MAX_WORD = 8
    MERGE_SPAN = 5
    TOKEN_KINDS = %i[word collocation measure_word character].freeze
    KIND_PREFERENCE = %i[word collocation measure_word character].freeze

    Token = Data.define(:kind, :text, :lexeme, :chars)

    class << self
      def vocabulary
        @vocabulary ||= {}
        @vocabulary[:zh_tw] ||= begin
          words = Lexeme.where(kind: %i[word collocation]).where("length(text) >= 2").pluck(:text).to_set
          words |= SegmentationVocabulary.words
          {words: words, max: [words.map(&:length).max || 2, MAX_WORD].min, mixed: mixed_pattern(words)}
        end
      end

      def reset_vocabulary!
        @vocabulary = nil
      end

      private

      def mixed_pattern(words)
        specials = words.reject { |word| word.each_char.all? { |char| char.match?(HAN) } }
        return nil if specials.empty?

        parts = specials.sort_by { |word| -word.length }.map do |word|
          head = word[0].match?(ALNUM) ? "(?<![A-Za-z0-9])" : ""
          tail = word[-1].match?(ALNUM) ? "(?![A-Za-z0-9])" : ""
          "#{head}#{Regexp.escape(word)}#{tail}"
        end

        Regexp.new(parts.join("|"))
      end
    end

    def initialize(locale: I18n.locale)
      @locale = locale
    end

    def analyze(text)
      analyze_lines([text]).first || []
    end

    def analyze_lines(lines)
      batches = Array(lines).map do |line|
        line = line.to_s.strip
        line.blank? ? [] : tokenize(line, known_words)
      end

      batches = merge_longest(batches)
      index = index_for(batches)
      batches.map { |tokens| build(tokens, index) }
    end

    def analyze_map(lines)
      lines = Array(lines).uniq
      analyze_lines(lines).each_with_index.to_h { |tokens, index| [lines[index], tokens] }
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

    MONTH_HEADS = %w[正 一 二 三 四 五 六 七 八 九 十 十一 十二].to_set.freeze
    DAY_TAILS = %w[一 二 三 四 五 六 七 八 九 十].to_set.freeze

    def tokenize(text, words)
      pattern = self.class.vocabulary[:mixed]
      return normalize(tokenize_plain(text, words)) if pattern.nil?

      result = []
      cursor = 0
      text.scan(pattern) do
        match = Regexp.last_match
        result.concat(tokenize_plain(text[cursor...match.begin(0)], words)) if match.begin(0) > cursor
        result << [:word, match[0]]
        cursor = match.end(0)
      end

      result.concat(tokenize_plain(text[cursor..], words)) if cursor < text.length
      normalize(result)
    end

    def normalize(tokens)
      out = []
      index = 0

      while index < tokens.length
        kind, text = tokens[index]
        second = tokens[index + 1]
        third = tokens[index + 2]

        if kind != :literal &&
            second &&
            second[1] == "月初" &&
            MONTH_HEADS.include?(text) &&
            third &&
            DAY_TAILS.include?(third[1])
          out << [:word, "#{text}月"] << [:word, "初#{third[1]}"]
          index += 3
        elsif text == "媽" && second && second[1] == "祖廟"
          out << [:word, "媽祖"] << [:char, "廟"]
          index += 2
        elsif text == "好" && second && second[1] == "兄弟" && third && third[1] == "們"
          out << [:word, "好兄弟"]
          index += 2
        else
          out << tokens[index]
          index += 1
        end
      end

      out
    end

    def tokenize_plain(text, words)
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

    def merge_longest(batches)
      vocabulary = known_words
      candidates = batches
        .flat_map { |tokens| joins_in(tokens).keys }
        .uniq
        .reject { |text| vocabulary.include?(text) }
      return batches if candidates.empty?

      known = Lexeme.where(kind: TOKEN_KINDS, text: candidates).distinct.pluck(:text).to_set
      return batches if known.empty?

      batches.map { |tokens| fold(tokens, known) }
    end

    def joins_in(tokens)
      spans = {}
      tokens.each_index do |start|
        next if tokens[start].first == :literal

        text = +""
        (start...[start + MERGE_SPAN, tokens.length].min).each do |stop|
          break if tokens[stop].first == :literal

          text += tokens[stop].last
          break if text.length > MAX_WORD

          spans[text] = [start, stop] if stop > start
        end
      end

      spans
    end

    def fold(tokens, known)
      out = []
      index = 0

      while index < tokens.length
        span = longest_span(tokens, index, known)
        if span
          out << [:word, tokens[index..span].map(&:last).join]
          index = span + 1
        else
          out << tokens[index]
          index += 1
        end
      end

      out
    end

    def longest_span(tokens, start, known)
      return nil if tokens[start].first == :literal

      text = +""
      best = nil
      (start...[start + MERGE_SPAN, tokens.length].min).each do |stop|
        break if tokens[stop].first == :literal

        text += tokens[stop].last
        break if text.length > MAX_WORD

        best = stop if stop > start && known.include?(text)
      end

      best
    end

    def index_for(batches)
      han_texts = batches.flat_map { |tokens| tokens.reject { |kind, _| kind == :literal }.map(&:last) }.uniq
      return {lexemes: {}, chars: {}} if han_texts.empty?

      lexemes = Lexeme
        .where(kind: TOKEN_KINDS, text: han_texts)
        .sort_by { |lexeme| KIND_PREFERENCE.index(lexeme.kind.to_sym) || KIND_PREFERENCE.size }
        .reverse
        .index_by(&:text)
      char_texts = han_texts.flat_map(&:chars).uniq - lexemes.keys
      chars = lexemes.select { |text, lexeme| text.length == 1 && lexeme.character? }
      chars = chars.merge(Lexeme.where(kind: :character, text: char_texts).index_by(&:text))
      {lexemes:, chars:}
    end

    def build(tokens, index)
      lexemes = index[:lexemes]
      chars = index[:chars]

      tokens.map do |kind, text|
        next Token.new(kind: :literal, text:, lexeme: nil, chars: []) if kind == :literal

        components = text.chars.filter_map { |char| chars[char] }
        Token.new(kind:, text:, lexeme: lexemes[text], chars: components)
      end
    end
  end
end
