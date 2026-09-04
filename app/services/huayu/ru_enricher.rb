# frozen_string_literal: true

module Huayu
  class RuEnricher
    PATH = AppData.path("huayu/ru_glosses.json")

    OWNED_ELSEWHERE = %i[sentence].freeze

    def initialize(path: PATH, curated: CuratedGlosses.new)
      @path = Pathname(path)
      @curated = curated
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      glosses = JSON.parse(@path.read)
      counts = Hash.new(0)

      glosses.each_slice(500) do |slice|
        texts = slice.to_h
        Lexeme.where(text: texts.keys).where.not(kind: OWNED_ELSEWHERE).find_each do |lexeme|
          ru = texts[lexeme.text].to_s.strip
          next if ru.empty? || lexeme.meanings["ru"] == ru
          next if owned_by_a_page?(lexeme)

          counts[lexeme.meanings["ru"].to_s.empty? ? :filled : :replaced] += 1
          lexeme.meanings = lexeme.meanings.merge("ru" => ru)
          lexeme.save!
        end
      end

      counts[:glosses] = glosses.size
      counts
    end

    private

    def owned_by_a_page?(lexeme)
      Lexeme::DICTIONARY_KINDS.include?(lexeme.kind.to_sym) && @curated.owns?(lexeme.text, "ru")
    end
  end
end
