# frozen_string_literal: true

module Huayu
  class WordFrequency
    PATH = AppData.path("huayu/corpus_frequency.json")

    UNSEEN_WORD = 0.5
    UNSEEN_CHAR = 0.2
    CACHE_LIMIT = 100_000

    class << self
      def instance
        @instance ||= new
      end

      delegate :word_cost, :char_cost, :per_million, :adjusted, :dispersion, :zipf, :known?, :size, to: :instance

      def reset!
        @instance = nil
      end
    end

    def initialize(path: PATH)
      payload = File.exist?(path) ? JSON.parse(File.read(path)) : {"words" => {}, "chars" => {}}
      @words = payload["words"] || {}
      @chars = payload["chars"] || {}
      adjusted = payload["adjusted"] || {}
      @adjusted_words = adjusted["words"] || @words
      @adjusted_chars = adjusted["chars"] || @chars
      @dispersion = (payload["dispersion"] || {})["words"] || {}
      total = @words.values.sum + @chars.values.sum
      @total = total.positive? ? total.to_f : 1.0
      @word_costs = {}
      @char_costs = {}
      @unseen_word = -Math.log(UNSEEN_WORD / @total)
      @unseen_char = -Math.log(UNSEEN_CHAR / @total)
    end

    def word_cost(token)
      cached = @word_costs[token]
      return cached if cached

      @word_costs = {} if @word_costs.size >= CACHE_LIMIT
      count = @words[token]
      @word_costs[token] = count ? -Math.log(count / @total) : @unseen_word
    end

    def char_cost(char)
      @char_costs[char] ||= begin
        count = @chars[char]
        count ? -Math.log(count / @total) : @unseen_char
      end
    end

    def per_million(token)
      (token.length == 1 ? @chars[token] : @words[token]) || 0
    end

    def adjusted(token)
      (token.length == 1 ? @adjusted_chars[token] : @adjusted_words[token]) || 0
    end

    def dispersion(token)
      @dispersion[token]
    end

    def zipf(token)
      value = adjusted(token)
      return nil if value.zero?

      (Math.log10(value * 1_000) * 10).round / 10.0
    end

    def known?(token)
      @words.key?(token)
    end

    def size
      @words.size
    end
  end
end
