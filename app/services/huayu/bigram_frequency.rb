# frozen_string_literal: true

module Huayu
  class BigramFrequency
    PATH = AppData.path("huayu/bigram_frequency.json")
    START = "<s>"
    TOKEN_PENALTY = 0.0
    FLOOR = 1e-9
    CACHE_LIMIT = 100_000

    class << self
      def instance
        @instance ||= new
      end

      delegate :cost, :available?, :knows?, :size, :cached_entries, to: :instance

      def reset!
        @instance = nil
      end
    end

    def initialize(path: PATH)
      payload = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      @table = {}
      (payload["bigram"] || {}).each do |context, followers|
        followers.each { |token, value| (@table[token] ||= {})[context] = value }
      end

      @weights = payload["lambda"] || {}
      @continuation = payload["continuation"] || {}
      if @continuation.values.any? { |value| value > 1 }
        @continuation = @continuation.transform_values { |value| value / 1_000_000.0 }
      end

      @unigram = Huayu::WordFrequency.instance
      @cache = {}
      @cached = 0
    end

    def available?
      @table.any?
    end

    def size
      @table.size
    end

    def knows?(token)
      @table.key?(token) || @continuation.key?(token)
    end

    def cached_entries
      @cached
    end

    def cost(context, token)
      bucket = @cache[context]
      cached = bucket && bucket[token]
      return cached if cached

      probability = (@table[token] || {})[context].to_f
      probability += @weights[context].to_f * @continuation[token].to_f
      probability = FLOOR * fallback(token) if probability <= 0.0
      value = -Math.log(probability) + TOKEN_PENALTY

      if @cached >= CACHE_LIMIT
        @cache = {}
        @cached = 0
        bucket = nil
      end

      (bucket || (@cache[context] ||= {}))[token] = value
      @cached += 1
      value
    end

    private

    def fallback(token)
      value = @unigram.per_million(token)
      value.positive? ? value / 1_000_000.0 : FLOOR
    end
  end
end
