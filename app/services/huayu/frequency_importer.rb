# frozen_string_literal: true

module Huayu
  class FrequencyImporter
    CHARS_PATH = AppData.path("dictionaries/sources/moe/hanzi_table_202209.xlsx")
    WORDS_PATH = AppData.path("dictionaries/sources/moe/word_table_14452_202504.xlsx")

    def initialize(chars_path: CHARS_PATH, words_path: WORDS_PATH)
      @chars_path = Pathname(chars_path)
      @words_path = Pathname(words_path)
    end

    def call
      {
        characters: import(@chars_path, :character, text_col: 2, freq_col: 5),
        words: import(@words_path, :word, text_col: 2, freq_col: 6)
      }
    end

    private

    def import(path, kind, text_col:, freq_col:)
      return {ranked: 0, applied: 0, missing: 0} unless path.exist?

      ranks = ranks_from(path, text_col:, freq_col:)
      applied = 0
      missing = 0

      ranks.each_slice(1000) do |slice|
        texts = slice.to_h
        found = Lexeme.where(kind: Lexeme.kinds[kind], text: texts.keys).index_by(&:text)
        texts.each do |text, rank|
          lexeme = found[text]
          if lexeme.nil?
            missing += 1
            next
          end

          next if lexeme.data["freq_rank"] == rank

          lexeme.update!(data: lexeme.data.merge("freq_rank" => rank))
          applied += 1
        end
      end

      {ranked: ranks.size, applied:, missing:}
    end

    def ranks_from(path, text_col:, freq_col:)
      require "roo"

      sheet = Roo::Spreadsheet.open(path.to_s).sheet(0)
      best = {}

      (2..sheet.last_row).each do |row|
        text = sheet.cell(row, text_col).to_s.strip
        next if text.empty?

        freq = sheet.cell(row, freq_col).to_s.gsub(/[^0-9.]/, "").to_f
        best[text] = freq if best[text].nil? || freq > best[text]
      end

      best.sort_by { |_text, freq| -freq }.each_with_index.to_h { |(text, _freq), index| [text, index + 1] }
    end
  end
end
