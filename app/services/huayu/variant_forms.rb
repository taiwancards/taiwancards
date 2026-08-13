# frozen_string_literal: true

module Huayu
  class VariantForms
    TAI = %w[檯 臺 台].freeze
    TAIWAN_TAI = %w[檯 臺 台].freeze
    PLAIN_TAI = %w[檯 台 臺].freeze
    TAIWAN = /\A[臺台](?:灣|北|中|南|東|語|幣|獨|商|胞|鐵|客|積|美|日|股|僑|大)|[臺台](?:灣|幣|獨|語)/

    GROUPS = [
      TAI,
      %w[裡 裏],
      %w[麵 麪],
      %w[汙 污],
      %w[戶 户],
      %w[衛 衞],
      %w[兌 兑],
      %w[峰 峯],
      %w[群 羣],
      %w[溫 温],
      %w[床 牀],
      %w[脣 唇]
    ].freeze

    FORMS = GROUPS.flat_map { |group| group.map { |char| [char, group] } }.to_h.freeze
    RANKS = GROUPS.flat_map { |group| group.each_with_index.map { |char, index| [char, index] } }.to_h.freeze
    SPELLINGS = 27
    LAST = Float::INFINITY

    def call(lexeme)
      texts = spellings(lexeme.text)
      return [] if texts.empty?

      rows = Lexeme
        .visible
        .where(kind: Lexeme::DICTIONARY_KINDS, text: texts)
        .includes(:senses)
        .order(:kind)
        .uniq(&:text)
      rows.size > 1 ? rows.sort_by { |row| rank(row) } : []
    end

    def spellings(text)
      chars = text.to_s.each_char.to_a
      return [] if chars.length < 2 || chars.none? { |char| FORMS.key?(char) }

      options = chars.map { |char| FORMS[char] || [char] }
      return [] if options.reduce(1) { |carry, forms| carry * forms.length } > SPELLINGS

      options.first.product(*options.drop(1)).map(&:join)
    end

    def taiwan?(text) = text.to_s.match?(TAIWAN)

    private

    def rank(lexeme)
      [glyphs(lexeme.text), -lexeme.senses.size, lexeme.freq_rank || LAST, lexeme.text]
    end

    def glyphs(text)
      tai = taiwan?(text) ? TAIWAN_TAI : PLAIN_TAI

      text.each_char.sum { |char| TAI.include?(char) ? tai.index(char) : RANKS.fetch(char, 0) }
    end
  end
end
