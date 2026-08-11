# frozen_string_literal: true

class WordCover
  LONGEST = 6
  SKIP = /\A[[:punct:][:space:]　０-９0-9A-Za-zＡ-Ｚａ-ｚ①-⑨＿％－—]+\z/

  Result = Data.define(:spans) do
    def tokens = spans.map(&:first)

    def unknown = spans.reject(&:last).map(&:first)

    def missing = unknown.uniq

    def counted = spans.sum { |text, _known| text.length }

    def missed = unknown.sum(&:length)

    def covered? = unknown.empty?

    def rate = counted.zero? ? 1.0 : (counted - missed).fdiv(counted)
  end

  def initialize(words, longest: LONGEST, skip: SKIP)
    @words = words
    @longest = longest
    @skip = skip
  end

  def call(text)
    chars = text.to_s.chars
    size = chars.length
    cost = Array.new(size + 1)
    step = Array.new(size + 1)
    cost[0] = 0

    (0...size).each do |index|
      here = cost[index]
      next if here.nil?

      moves(chars, index, size).each do |token, known|
        stop = index + token.length
        price = here + (known ? 0 : 1)
        next if cost[stop] && cost[stop] <= price

        cost[stop] = price
        step[stop] = [index, token, known]
      end
    end

    Result.new(spans: trail(step, size))
  end

  private

  def moves(chars, index, size)
    return [[chars[index], true]] if chars[index].match?(@skip)

    list = []
    [@longest, size - index].min.downto(1) do |length|
      word = chars[index, length].join
      list << [word, true] if @words.include?(word)
    end

    list << [chars[index], false]
    list
  end

  def trail(step, size)
    spans = []
    at = size

    while at.positive?
      from, token, known = step[at]
      spans.unshift([token, known]) unless token.match?(@skip)
      at = from
    end

    spans
  end
end
