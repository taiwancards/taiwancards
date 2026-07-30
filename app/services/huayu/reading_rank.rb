# frozen_string_literal: true

module Huayu
  class ReadingRank
    def weights
      @weights ||= begin
        table = Hash.new { |all, id| all[id] = Hash.new(0.0) }
        rows.each { |row| table[row["child_id"]][row["reading"]] = row["weight"].to_f }
        table
      end
    end

    SPOKEN = {
      "都" => {"ㄉㄡ" => 10.0},
      "和" => {"ㄏㄢˋ" => 0.002}
    }.freeze

    def order(lexeme, char_weights = weights[lexeme.id])
      readings = lexeme.reading_set
      return readings if readings.size < 2

      audio = audio_index(lexeme.text)
      floors = SPOKEN[lexeme.text] || {}
      readings
        .each_with_index
        .sort_by { |reading, index|
          weight = [char_weights[reading["pinyin"]] || 0.0, floors[reading["zhuyin"]] || 0.0].max
          [-weight, audio.fetch(reading["zhuyin"], AUDIO_MISS), index]
        }
        .map(&:first)
    end

    private

    AUDIO_MISS = 99

    def audio_index(text)
      MoeAudio.readings(text).each_with_index.to_h { |reading, index| [reading["zhuyin"], index] }
    end

    def rows
      ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array(
          [
            <<~SQL
              SELECT links.child_id, links.reading,
                     SUM(1.0 / NULLIF((parent.data->>'freq_rank')::int, 0)) AS weight
              FROM lexeme_links links
              JOIN lexemes parent ON parent.id = links.parent_id
              JOIN lexemes child ON child.id = links.child_id
              WHERE links.reading IS NOT NULL
                AND parent.kind IN (:word_kinds)
                AND child.kind = :character
              GROUP BY links.child_id, links.reading
            SQL
              .squish,
            {
              word_kinds: Lexeme.kinds.values_at("word", "collocation"),
              character: Lexeme.kinds.fetch("character")
            }
          ]
        )
      )
    end
  end
end
