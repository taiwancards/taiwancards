# frozen_string_literal: true

module Lexemes
  class RegisterMix
    STYLE_COUNT = ContentSource.registers.size
    PRIOR = 12.0
    SENTENCE_PRIOR = 1.0
    MIN_TOKENS = 50_000
    KINDS = %i[word collocation].freeze

    def initialize(io: $stdout, min_tokens: MIN_TOKENS, prior: PRIOR)
      @io = io
      @min_tokens = min_tokens
      @prior = prior
    end

    def call
      cleared = clear
      updated = update
      sentences = styles.positive? ? update_sentences : 0
      @io.puts(
        "register mix: words and collocations #{updated}, sentences #{sentences}, old rows dropped #{cleared}"
      )
      {updated:, sentences:, cleared:}
    end

    private

    def clear
      execute(
        <<~SQL
          UPDATE lexemes
          SET data = data - 'register_mix' - 'register_n' - 'register_eff'
          WHERE data ?| array['register_mix', 'register_n', 'register_eff']
        SQL
      )
    end

    SCRATCH = %w[register_counts register_informative register_patch].freeze

    def build(name, select)
      connection.execute("DROP TABLE IF EXISTS #{name}")
      connection.execute("CREATE UNLOGGED TABLE #{name} AS #{select}")
      connection.execute("ANALYZE #{name}")
    end

    def apply(select)
      build("register_patch", select)
      connection.execute("CREATE UNIQUE INDEX ON register_patch (id)")
      connection.execute("ANALYZE register_patch")
      execute(
        "UPDATE lexemes SET data = data || register_patch.patch " \
          "FROM register_patch WHERE lexemes.id = register_patch.id"
      )
    end

    def drop_scratch
      SCRATCH.each { |name| connection.execute("DROP TABLE IF EXISTS #{name}") }
    end

    def connection = Lexeme.connection

    def update
      build("register_counts", counts_sql)
      apply(word_patch_sql)
    ensure
      drop_scratch
    end

    def update_sentences
      build("register_informative", informative_sql)
      apply(sentence_patch_sql)
    ensure
      drop_scratch
    end

    def counts_sql
      <<~SQL
        WITH samples AS (
          SELECT DISTINCT lcs.lexeme_id AS sentence_id, sources.register AS register
          FROM lexeme_content_sources lcs
          JOIN content_sources sources ON sources.id = lcs.content_source_id
          WHERE sources.style_sample AND sources.register IS NOT NULL
        ),
        stored AS (
          SELECT word.id AS id, samples.register AS register, count(*)::numeric AS n
          FROM lexemes sentence
          JOIN samples ON samples.sentence_id = sentence.id
          CROSS JOIN LATERAL jsonb_array_elements_text(sentence.data -> 'segments') AS seg(unit)
          JOIN lexemes word
            ON word.kind IN (#{kind_list})
           AND word.text = seg.unit
          WHERE sentence.kind = #{Lexeme.kinds.fetch("sentence")}
          GROUP BY 1, 2
        ),
        measured AS (
          SELECT word.id AS id, sources.register AS register, sum(rs.n)::numeric AS n
          FROM register_samples rs
          JOIN content_sources sources ON sources.id = rs.content_source_id
          JOIN lexemes word ON word.kind IN (#{kind_list}) AND word.text = rs.text
          WHERE sources.style_sample AND sources.register IS NOT NULL
          GROUP BY 1, 2
        )
        SELECT id, register, sum(n) AS n
        FROM (SELECT * FROM stored UNION ALL SELECT * FROM measured) pooled
        GROUP BY 1, 2
      SQL
    end

    def word_patch_sql
      <<~SQL
          WITH counts AS (
            SELECT id, register, n FROM register_counts
          ),
          totals AS (
            SELECT register, sum(n) AS total
            FROM counts
            GROUP BY register
            HAVING sum(n) >= #{@min_tokens}
          ),
          weights AS (
            SELECT register, avg(total) OVER () / total AS weight, count(*) OVER () AS styles
            FROM totals
          ),
          scaled AS (
            SELECT counts.id,
                   counts.register,
                   counts.n AS n,
                   weights.styles AS styles,
                   counts.n * weights.weight AS x,
                   counts.n * weights.weight * weights.weight AS q
            FROM counts JOIN weights USING (register)
          ),
          sums AS (
            SELECT id,
                   max(styles) AS styles,
                   sum(n) AS raw_n,
                   sum(x) AS x_total,
                   sum(q) AS q_total,
                   #{slots}
            FROM scaled
            GROUP BY id
          ),
          mixes AS (
            SELECT id,
                   jsonb_build_object(
                     'register_mix', jsonb_build_array(#{fractions}),
                     'register_n', raw_n,
                     'register_eff', round(x_total * x_total / q_total, 1)
                   ) AS patch
            FROM sums
            WHERE x_total > 0 AND q_total > 0
          )
        SELECT id, patch FROM mixes
      SQL
    end

    def informative_sql
      <<~SQL
        SELECT word.id AS id,
               word.data -> 'register_mix' AS mix,
               (
                 SELECT coalesce(sum(share * ln(share * #{styles})), 0)
                 FROM jsonb_array_elements_text(word.data -> 'register_mix') AS slot(value)
                 CROSS JOIN LATERAL (SELECT nullif(slot.value, '')::numeric AS share) AS parsed
                 WHERE share > 0
               ) AS weight
        FROM lexemes word
        WHERE word.kind IN (#{kind_list}) AND word.data ? 'register_mix'
      SQL
    end

    def sentence_patch_sql
      <<~SQL
        WITH parts AS (
            SELECT sentence.id AS id, informative.weight AS weight, informative.mix AS mix
            FROM lexemes sentence
            CROSS JOIN LATERAL jsonb_array_elements_text(sentence.data -> 'segments') AS seg(unit)
            JOIN lexemes word
              ON word.kind IN (#{kind_list})
             AND word.text = seg.unit
            JOIN register_informative informative ON informative.id = word.id
            WHERE sentence.kind = #{Lexeme.kinds.fetch("sentence")} AND informative.weight > 0
          ),
          sums AS (
            SELECT id,
                   count(*) AS words,
                   sum(weight) AS total,
                   #{sentence_slots}
            FROM parts
            GROUP BY id
          ),
          mixes AS (
            SELECT id,
                   jsonb_build_object(
                     'register_mix', jsonb_build_array(#{sentence_fractions}),
                     'register_n', words,
                     'register_eff', round(total, 2)
                   ) AS patch
            FROM sums
            WHERE total > 0
          )
          SELECT id, patch FROM mixes
      SQL
    end

    def styles
      @styles ||= Lexeme
        .connection
        .select_value(
          <<~SQL
            SELECT count(*)
            FROM jsonb_array_elements(
              coalesce(
                (SELECT data -> 'register_mix' FROM lexemes WHERE data ? 'register_mix' LIMIT 1),
                '[]'::jsonb
              )
            ) AS slot(value)
            WHERE slot.value <> 'null'::jsonb
          SQL
        )
        .to_i
    end

    def sentence_slots
      (0...STYLE_COUNT)
        .map { |register| "sum(weight * (mix ->> #{register})::numeric) AS m#{register}" }
        .join(",\n                   ")
    end

    def sentence_fractions
      (0...STYLE_COUNT)
        .map do |register|
          "CASE WHEN m#{register} IS NOT NULL " \
            "THEN round((m#{register} + #{SENTENCE_PRIOR} / #{styles}) / (total + #{SENTENCE_PRIOR}), 4) END"
        end
        .join(", ")
    end

    def slots
      (0...STYLE_COUNT)
        .map { |register| "coalesce(sum(x) FILTER (WHERE register = #{register}), 0) AS x#{register}" }
        .join(",\n                   ")
    end

    def fractions
      (0...STYLE_COUNT)
        .map do |register|
          "CASE WHEN EXISTS (SELECT 1 FROM totals WHERE totals.register = #{register}) " \
            "THEN round((x_total * x#{register} + #{@prior} * q_total / styles) " \
            "/ (x_total * x_total + #{@prior} * q_total), 4) END"
        end
        .join(", ")
    end

    def kind_list
      KINDS.map { |kind| Lexeme.kinds.fetch(kind.to_s) }.join(", ")
    end

    def execute(sql)
      Lexeme.connection.exec_update(sql, "register_mix")
    end
  end
end
