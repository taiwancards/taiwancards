# frozen_string_literal: true

module Huayu
  class SentenceMeaningFiller
    def initialize(io: $stdout)
      @io = io
    end

    def call
      entries = SentenceGlossStore.read
      if entries.empty?
        @io.puts("sentence gloss store is empty")
        return {filled: 0}
      end

      filled = fill_lexemes(entries)
      @io.puts(format("sentences glossed: %6d", filled))
      {filled:}
    end

    private

    def fill_lexemes(entries)
      updated = 0

      entries.each_slice(500) do |slice|
        by_text = slice.index_by(&:text)

        Lexeme.where(kind: :sentence, text: by_text.keys).find_each do |lexeme|
          entry = by_text[lexeme.text]
          meanings = {"en" => entry.en, "ru" => entry.ru}.compact_blank
          next if lexeme.meanings == meanings

          lexeme.update_columns(meanings: meanings, updated_at: Time.current)
          updated += 1
        end
      end

      updated
    end
  end
end
