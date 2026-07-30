# frozen_string_literal: true

module Huayu
  class ThesaurusImporter
    PATH = AppData.path("huayu/thesaurus.json")
    KINDS = %i[word collocation character].freeze
    FIELDS = %w[synonyms antonyms related collocates].freeze
    BATCH = 500

    def initialize(path: PATH)
      @table = File.exist?(path) ? JSON.parse(File.read(path)) : {}
    end

    def call
      return FIELDS.index_with(0) if @table.empty?

      known = Lexeme.where(kind: KINDS).pluck(:text).to_set
      filled = Hash.new(0)
      touched = []

      Lexeme.where(kind: KINDS).where(text: @table.keys).find_each(batch_size: BATCH) do |lexeme|
        entry = @table[lexeme.text]
        payload = FIELDS.to_h { |field| [field, keep(entry[field], known, lexeme.text)] }.compact_blank
        payload.each_key { |field| filled[field] += 1 }
        touched << lexeme.text

        data = lexeme.data.except(*FIELDS).merge(payload)
        lexeme.update_column(:data, data) if data != lexeme.data
      end

      clear_stale(touched.to_set)
      filled
    end

    private

    def keep(rows, known, text)
      Array(rows)
        .map { |row| row.is_a?(Hash) ? row["word"] : row }
        .select { |word| word.present? && word != text && known.include?(word) }
        .uniq
        .presence
    end

    def clear_stale(current)
      Lexeme
        .where(kind: KINDS)
        .where("data ?| array[:fields]", fields: FIELDS)
        .find_each(batch_size: BATCH) do |lexeme|
          next if current.include?(lexeme.text)

          lexeme.update_column(:data, lexeme.data.except(*FIELDS))
        end
    end
  end
end
