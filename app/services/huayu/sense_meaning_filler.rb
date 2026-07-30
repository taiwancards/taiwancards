# frozen_string_literal: true

module Huayu
  class SenseMeaningFiller
    def initialize(io: $stdout)
      @io = io
    end

    def call
      copied = copy_single_sense
      stored = apply_store
      @io.puts(format("senses filled from the entry: %6d", copied))
      @io.puts(format("senses filled from our glosses : %6d", stored))
      {copied:, stored:}
    end

    private

    def copy_single_sense
      LexemeSense.connection.exec_update(
        <<~SQL,
          WITH single AS (
            SELECT lexeme_id FROM lexeme_senses GROUP BY lexeme_id HAVING count(*) = 1
          )
          UPDATE lexeme_senses s
          SET meanings = jsonb_strip_nulls(
                jsonb_build_object(
                  'en', NULLIF(l.meanings->>'en', ''),
                  'ru', NULLIF(l.meanings->>'ru', '')
                )
              )
          FROM lexemes l, single
          WHERE s.lexeme_id = single.lexeme_id
            AND l.id = s.lexeme_id
            AND (COALESCE(l.meanings->>'en', '') <> '' OR COALESCE(l.meanings->>'ru', '') <> '')
            AND s.meanings = '{}'::jsonb
        SQL
              "copy_single_sense"
      )
    end

    def apply_store
      entries = SenseGlossStore.read
      return 0 if entries.empty?

      by_key = entries.group_by(&:word)
      lexemes = Lexeme.where(text: by_key.keys).pluck(:id, :text).to_h
      return 0 if lexemes.empty?

      rows = LexemeSense
        .where(lexeme_id: lexemes.keys)
        .pluck(:id, :lexeme_id, :gloss_zh, :meanings)
        .filter_map do |id, lexeme_id, gloss_zh, stored|
          entry = by_key[lexemes[lexeme_id]]&.find { |candidate| candidate.zh == gloss_zh }
          next if entry.nil?

          meanings = stored.merge({"en" => entry.en.presence, "ru" => entry.ru.presence}.compact)
          next if meanings == stored

          [id, meanings]
        end

      Bulk.patch(target: "lexeme_senses", columns: {"meanings" => "jsonb"}, rows: rows)
    end
  end
end
