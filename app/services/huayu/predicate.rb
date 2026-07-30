# frozen_string_literal: true

module Huayu
  class Predicate
    MARKER = /[是有沒未無不別非也都就已曾將會能可要應須得讓使把被很最更仍還再才只又則而並卻尚均皆亦乃即甚遂竟太越較頗嗎呢吧啊了呀喔啦嘛哦？！]/
    SHORT = 12
    MOE_VERBAL = %w[動 形].freeze

    def initialize
      @tocfl = Lexeme
        .where(kind: %i[word character])
        .where("data ? 'pos'")
        .pluck(:text, Arel.sql("data ->> 'pos'"))
        .to_h
      @moe = Lexeme
        .where(kind: %i[word character])
        .where("data ? 'pos_moe'")
        .pluck(:text, Arel.sql("data -> 'pos_moe'"))
        .to_h
    end

    def missing?(text, words:, official: false)
      return false unless words.is_a?(Array) && words.any?

      marked = text.to_s.match?(MARKER)
      return false if marked && !official

      tocfl = words.any? { |word| tocfl_verb?(word) }
      return true if !marked && !tocfl && words.none? { |word| moe_verb?(word) }
      return true if !marked && !tocfl && text.to_s.scan(/\p{Han}/).length < SHORT

      official && list_item?(words)
    end

    private

    def list_item?(words)
      tagged = words.filter_map { |word| @tocfl[word] }
      return false if tagged.length < words.length

      tagged.none? { |tag| verbal_tag?(tag) }
    end

    def tocfl_verb?(word)
      verbal_tag?(@tocfl[word])
    end

    def moe_verb?(word)
      labels = @moe[word]
      labels.is_a?(Array) && labels.intersect?(MOE_VERBAL)
    end

    def verbal_tag?(tag)
      tag.to_s.split("/").any? { |part| part.start_with?("V") }
    end
  end
end
