# frozen_string_literal: true

module Huayu
  class RuEnricher
    PATH = AppData.path("huayu/ru_glosses.json")

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      glosses = JSON.parse(@path.read)
      counts = Hash.new(0)

      glosses.each_slice(500) do |slice|
        texts = slice.to_h
        Lexeme.where(text: texts.keys).find_each do |lexeme|
          ru = texts[lexeme.text].to_s.strip
          next if ru.empty? || lexeme.meanings["ru"] == ru

          counts[lexeme.meanings["ru"].to_s.empty? ? :filled : :replaced] += 1
          lexeme.meanings = lexeme.meanings.merge("ru" => ru)
          lexeme.save!
        end
      end

      counts[:glosses] = glosses.size
      counts
    end
  end
end
