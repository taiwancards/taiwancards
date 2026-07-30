# frozen_string_literal: true

module Huayu
  class CollocationMeaningFiller
    def initialize(io: $stdout)
      @io = io
    end

    def call
      entries = CollocationGlossStore.read
      if entries.empty?
        @io.puts("collocation gloss store is empty")
        return {filled: 0}
      end

      filled = fill_lexemes(entries)
      @io.puts(format("collocations glossed: %6d", filled))
      {filled:}
    end

    private

    def fill_lexemes(entries)
      updated = 0

      entries.each_slice(500) do |slice|
        by_text = slice.index_by(&:text)

        Lexeme.where(kind: :collocation, text: by_text.keys).find_each do |lexeme|
          entry = by_text[lexeme.text]
          meanings = lexeme
            .meanings
            .merge(
              {"en" => entry.en.presence, "ru" => entry.ru.presence}.compact
            ) { |_key, old, fresh| old.to_s.strip.presence || fresh }
          next if meanings == lexeme.meanings

          lexeme.update_columns(meanings: meanings)
          updated += 1
        end
      end

      updated
    end
  end
end
