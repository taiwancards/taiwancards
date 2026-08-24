# frozen_string_literal: true

module Huayu
  class ReadingRank
    MIN_EVIDENCE = 3
    AUDIO_MISS = 99
    UNGRADED = 99
    NO_USAGE = {weight: 0.0, graded: 0, band: UNGRADED}.freeze

    SPOKEN = {
      "都" => {"ㄉㄡ" => 10.0},
      "給" => {"ㄍㄟˇ" => 10.0},
      "和" => {"ㄏㄢˋ" => 0.002},
      "更" => {"ㄍㄥˋ" => 10.0},
      "省" => {"ㄕㄥˇ" => 10.0},
      "署" => {"ㄕㄨˇ" => 10.0},
      "屏" => {"ㄆㄧㄥˊ" => 10.0},
      "倡" => {"ㄔㄤˋ" => 10.0},
      "蕃" => {"ㄈㄢ" => 10.0},
      "呀" => {"˙ㄧㄚ" => 10.0},
      "吧" => {"˙ㄅㄚ" => 10.0},
      "啦" => {"˙ㄌㄚ" => 10.0}
    }.freeze

    def weights
      @weights ||= begin
        table = Hash.new { |all, id| all[id] = {} }
        rows.each do |row|
          table[row["child_id"]][row["reading"]] = {
            weight: row["weight"].to_f,
            graded: row["graded"].to_i,
            band: row["band"]&.to_i || UNGRADED
          }
        end

        table
      end
    end

    def order(lexeme, usage = weights[lexeme.id])
      readings = lexeme.reading_set
      return readings if readings.size < 2

      floors = SPOKEN[lexeme.text] || {}
      return readings if floors.empty? && !decisive?(usage)

      audio = audio_index(lexeme.text)
      readings
        .each_with_index
        .sort_by { |reading, index|
          entry = usage.fetch(reading["pinyin"], NO_USAGE)
          weight = [entry[:weight], floors[reading["zhuyin"]] || 0.0].max
          [-weight, -entry[:graded], audio.fetch(reading["zhuyin"], AUDIO_MISS), index]
        }
        .map(&:first)
    end

    private

    def decisive?(usage)
      leader = usage.values.max_by { |entry| [entry[:weight], entry[:graded]] }
      return false if leader.nil? || leader[:graded] < MIN_EVIDENCE

      usage.each_value.none? { |entry| entry[:band] < leader[:band] }
    end

    def audio_index(text)
      MoeAudio.readings(text).each_with_index.to_h { |reading, index| [reading["zhuyin"], index] }
    end

    def rows
      ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array(
          [
            <<~SQL
              SELECT links.child_id, links.reading,
                     SUM(1.0 / NULLIF((parent.data->>'freq_rank')::int, 0)) AS weight,
                     count(*) FILTER (
                       WHERE parent.data ? 'tocfl_level' OR (parent.data->>'tbcl_grade') IS NOT NULL
                     ) AS graded,
                     min(
                       least(
                         coalesce(array_position(ARRAY[:tocfl]::text[], parent.data->>'tocfl_level') - 1, :ungraded),
                         coalesce(array_position(ARRAY[:tbcl]::text[], parent.data->>'tbcl_grade') - 1, :ungraded)
                       )
                     ) AS band
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
              character: Lexeme.kinds.fetch("character"),
              tocfl: SentenceProfile::TOCFL_LEVELS,
              tbcl: SentenceProfile::TBCL_GRADES,
              ungraded: UNGRADED
            }
          ]
        )
      )
    end
  end
end
