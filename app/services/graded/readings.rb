# frozen_string_literal: true

module Graded
  class Readings
    HAN = /\p{Han}/
    Line = Data.define(:zhuyin, :pinyin)

    def initialize(analyzer: Huayu::TextAnalyzer.new)
      @analyzer = analyzer
    end

    def lines(text)
      chunks = text.lines.map { |line| @analyzer.segment(line.zh) }
      preload(chunks.flatten)
      text.lines.zip(chunks).to_h { |line, tokens| [line.zh, compose(tokens)] }
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

      entry = @entries[token]
      return [entry.readings["zhuyin"], entry.readings["pinyin"]] if entry&.readings&.dig("zhuyin").present?

      spelled = token.chars.map { |char| @entries[char] }
      [
        spelled.map { |one| one&.readings&.dig("zhuyin") || "•" }.join(" "),
        spelled.map { |one| one&.readings&.dig("pinyin") || "?" }.join
      ]
    end

    def preload(tokens)
      wanted = (tokens + tokens.flat_map(&:chars)).uniq.select { |text| text.match?(HAN) }
      @entries = Lexeme
        .where(kind: %i[word character], text: wanted)
        .order(:kind)
        .index_by(&:text)
    end
  end
end
