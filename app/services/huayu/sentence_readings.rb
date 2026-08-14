# frozen_string_literal: true

module Huayu
  class SentenceReadings
    HAN = /\p{Han}/
    NEUTRAL = "˙"
    SPLITS = {"都會" => %w[都 會]}.freeze
    PREFERRED = {"和" => ["ㄏㄢˋ", "hàn"]}.freeze
    Line = Data.define(:zhuyin, :pinyin)

    def initialize(analyzer: TextAnalyzer.new)
      @analyzer = analyzer
    end

    def call(sentences)
      texts = Array(sentences).map(&:to_s).uniq.reject(&:blank?)
      return {} if texts.empty?

      chunks = texts.map { |text| resplit(@analyzer.segment(text)) }
      preload(chunks.flatten)
      texts.zip(chunks).to_h { |text, tokens| [text, compose(tokens)] }
    end

    private

    def resplit(tokens)
      tokens.each_with_index.flat_map do |token, index|
        parts = SPLITS[token]
        next [token] if parts.nil? || tokens[index + 1]&.start_with?("區")

        parts
      end
    end

    def compose(tokens)
      pairs = tokens.map { |token| reading_for(token) }
      Line.new(
        zhuyin: pairs.map(&:first).join(" ").squeeze(" ").strip,
        pinyin: pairs.map(&:last).join(" ").squeeze(" ").strip
      )
    end

    def reading_for(token)
      return [token, token] unless token.match?(HAN)

      PREFERRED[token] || read(entry_for(token)) || spell(token)
    end

    def entry_for(token)
      word = @words[token]
      return word if token.length > 1

      return word if word&.readings&.dig("zhuyin").to_s.start_with?(NEUTRAL)

      @chars[token] || word
    end

    def read(entry)
      zhuyin = entry&.readings&.dig("zhuyin")
      return nil if zhuyin.blank?

      [first_variant(zhuyin), first_variant(entry.readings["pinyin"].to_s)]
    end

    def first_variant(reading) = reading.split(" / ").first.to_s

    def spell(token)
      pairs = token.chars.map { |char| read(entry_for(char)) }
      [
        pairs.map { |pair| pair&.first || "•" }.join(" "),
        pairs.map { |pair| pair&.last || "?" }.join
      ]
    end

    def preload(tokens)
      wanted = (tokens + tokens.flat_map(&:chars)).uniq.select { |text| text.match?(HAN) }
      grouped = Lexeme.where(kind: %i[word character], text: wanted).group_by(&:kind)
      @words = grouped.fetch("word", []).index_by(&:text)
      @chars = grouped.fetch("character", []).index_by(&:text)
    end
  end
end
