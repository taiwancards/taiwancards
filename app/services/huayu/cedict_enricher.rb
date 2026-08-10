# frozen_string_literal: true

module Huayu
  class CedictEnricher
    PATH = AppData.path("dictionaries/cedict.json")

    def initialize(path: PATH)
      @dict = File.exist?(path) ? JSON.parse(File.read(path)) : {}
    end

    def call
      filled = Hash.new(0)
      return filled if @dict.empty?

      Lexeme.where(kind: %i[word character]).find_each(batch_size: 500) do |lexeme|
        entry = @dict[lexeme.text]
        next if entry.nil?

        changed = false
        broken = truncated?(lexeme)

        if (lexeme.readings["pinyin"].blank? || broken) && usable?(lexeme.text, entry["pinyin"])
          lexeme.readings = lexeme.readings.merge("pinyin" => entry["pinyin"])
          lexeme.readings = lexeme.readings.except("zhuyin") if broken
          filled[broken ? :repaired : :pinyin] += 1
          changed = true
        end

        pinyin = lexeme.readings["pinyin"]
        if lexeme.readings["zhuyin"].blank? && pinyin.present?
          zhuyin = Huayu::Zhuyin.from_pinyin(pinyin)
          if zhuyin.present?
            lexeme.readings = lexeme.readings.merge("zhuyin" => zhuyin)
            filled[:zhuyin] += 1
            changed = true
          end
        end

        if lexeme.meanings["en"].blank? && entry["glosses"].present?
          lexeme.meanings = lexeme.meanings.merge("en" => entry["glosses"].first(4).join("; "))
          filled[:en] += 1
          changed = true
        end

        lexeme.save! if changed
      end

      filled
    end

    private

    def truncated?(lexeme)
      ReadingForms.malformed?(lexeme.text, lexeme.readings["zhuyin"])
    end

    def usable?(text, pinyin)
      return false if pinyin.blank?

      !ReadingForms.malformed?(text, Huayu::Zhuyin.from_pinyin(pinyin))
    end
  end
end
