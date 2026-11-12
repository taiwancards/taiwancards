# frozen_string_literal: true

module Huayu
  class VariantForms
    TAI = %w[檯 臺 台].freeze
    TAIWAN_TAI = %w[檯 臺 台].freeze
    PLAIN_TAI = %w[檯 台 臺].freeze
    TAI_CHARS = /[台臺]/
    ALWAYS_TAIWAN_AFTER = "灣北"
    STAGES = "櫃舞平月後站陽窗講看擂吧戲歌亭樓燭燈硯妝理布手席令揮備告劑號班衛詢證通駛務記報播聞視電象文望景火魚"
    MORE_STAGES = "灶露炮砲跳拳鏡神祭頭刑獎射作術制銀帳換轉高上下登底滿如兄"
    PLACES_ELSEWHERE = "仙茅蒙天煙邢"
    COUNTERS = "一二兩三四五六七八九十百千萬幾數多每整單這那哪"
    NOT_TAIWAN_BEFORE = [STAGES, MORE_STAGES, PLACES_ELSEWHERE, COUNTERS].join
    STAGE_WORDS = "詞階長數地子燈上下柱布面秤鐘曆座基榭球步口前風車扇鉗戲"
    HONORIFICS = "端鑒篆鼎甫啟照駕"
    MAINLAND_PLACES = "州山兒"
    NOT_TAIWAN_AFTER = [STAGE_WORDS, HONORIFICS, MAINLAND_PLACES].join
    TO_TAIWAN = "來訪抵返回赴離旅在駐留居滯遊全對親反挺援保護愛賣擾繞犯攻侵治據"
    TAIWAN = /
      [臺台](?=[#{ALWAYS_TAIWAN_AFTER}])
      | (?<![#{NOT_TAIWAN_BEFORE}])[臺台](?=[^#{NOT_TAIWAN_AFTER}])
      | (?<=[#{TO_TAIWAN}])[臺台]\z
    /x

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

    WORDS = [
      %w[手錶 手表],
      %w[老闆 老板],
      %w[老闆娘 老板娘]
    ].freeze

    FORMS = GROUPS.flat_map { |group| group.map { |char| [char, group] } }.to_h.freeze
    RANKS = GROUPS.flat_map { |group| group.each_with_index.map { |char, index| [char, index] } }.to_h.freeze
    WORD_FORMS = WORDS.flat_map { |group| group.map { |text| [text, group] } }.to_h.freeze
    WORD_RANKS = WORDS.flat_map { |group| group.each_with_index.map { |text, index| [text, index] } }.to_h.freeze
    SPELLINGS = 27
    LAST = Float::INFINITY

    def initialize(user:)
      @user = user
    end

    def call(lexeme)
      texts = spellings(lexeme.text)
      return [] if texts.empty?

      rows = Lexeme
        .visible_to(@user)
        .where(kind: Lexeme::DICTIONARY_KINDS, text: texts)
        .includes(:senses)
        .order(:kind)
        .uniq(&:text)
      rows.size > 1 ? rows.sort_by { |row| rank(row) } : []
    end

    def spellings(text)
      WORD_FORMS.fetch(text.to_s) { glyph_spellings(text.to_s) }
    end

    def taiwan?(text) = text.to_s.match?(TAIWAN)

    def self.tai_twins(text)
      text = text.to_s
      return [] if text.length < 2 || !text.match?(TAI_CHARS)

      [text.tr("台", "臺"), text.tr("臺", "台")].uniq - [text]
    end

    def self.lookup(index, text)
      index.fetch(text) { tai_twins(text).filter_map { |twin| index[twin] }.first }
    end

    def self.taiwan_twins(text)
      text.to_s.match?(TAIWAN) ? tai_twins(text) : []
    end

    private

    def rank(lexeme)
      [glyphs(lexeme.text), -lexeme.senses.size, lexeme.freq_rank || LAST, lexeme.text]
    end

    def glyph_spellings(text)
      chars = text.each_char.to_a
      return [] if chars.length < 2 || chars.none? { |char| FORMS.key?(char) }

      options = chars.map { |char| FORMS[char] || [char] }
      return [] if options.reduce(1) { |carry, forms| carry * forms.length } > SPELLINGS

      options.first.product(*options.drop(1)).map(&:join)
    end

    def glyphs(text)
      taiwan = taiwan_positions(text)

      WORD_RANKS.fetch(text, 0) +
        text.each_char.with_index.sum { |char, index| glyph_rank(char, taiwan.include?(index)) }
    end

    def glyph_rank(char, taiwan)
      return RANKS.fetch(char, 0) unless TAI.include?(char)

      (taiwan ? TAIWAN_TAI : PLAIN_TAI).index(char)
    end

    def taiwan_positions(text)
      text.to_enum(:scan, TAIWAN).map { Regexp.last_match.begin(0) }.to_set
    end
  end
end
