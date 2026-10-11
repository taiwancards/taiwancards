# frozen_string_literal: true

module Huayu
  class SentenceReadings
    HAN = /\p{Han}/
    Line = Data.define(:zhuyin, :pinyin)

    def initialize(analyzer: TextAnalyzer.new)
      @analyzer = analyzer
    end

    def call(sentences)
      texts = Array(sentences).map(&:to_s).uniq.reject(&:blank?)
      return {} if texts.empty?

      chunks = texts.map { |text| SpokenReading.resplit(@analyzer.segment(text)) }
      preload(chunks.flatten)
      texts.zip(chunks).to_h { |text, tokens| [text, compose(tokens)] }
    end

    private

    def compose(tokens)
      pairs = tokens.map { |token| reading_for(token) }
      Line.new(
        zhuyin: pairs.map(&:first).join(" ").squeeze(" ").strip,
        pinyin: pairs.map(&:last).join(" ").squeeze(" ").strip
      )
    end

    def reading_for(token)
      return [token, token] unless token.match?(HAN)

      read(spoken(token)) || spell(token)
    end

    def spoken(text, standalone: true) = SpokenReading.pick(@lexemes.fetch(text, []), standalone:)

    def read(readings)
      zhuyin = readings&.dig("zhuyin")
      return nil if zhuyin.blank?

      [first_variant(zhuyin), first_variant(readings["pinyin"].to_s)]
    end

    def first_variant(reading) = reading.split(" / ").first.to_s

    def spell(token)
      pairs = SpokenReading
        .pieces(token, -> (text) { SpokenReading.word?(@lexemes[text]) })
        .map { |piece| read(spoken(piece, standalone: piece.length > 1)) }
      [
        pairs.map { |pair| pair&.first || "•" }.join(" "),
        pairs.map { |pair| pair&.last || "?" }.join
      ]
    end

    def known?(text) = spoken(text).present?

    def preload(tokens)
      wanted = (tokens + tokens.flat_map(&:chars)).uniq.select { |text| text.match?(HAN) }
      @lexemes = SpokenReading.lexemes_for(wanted)
      unknown = tokens.uniq.select { |token| token.length > 1 && token.match?(HAN) && !known?(token) }
      inside = unknown.flat_map { |token| SpokenReading.substrings(token) }.uniq - @lexemes.keys
      @lexemes.merge!(SpokenReading.lexemes_for(inside)) if inside.any?
    end
  end
end
