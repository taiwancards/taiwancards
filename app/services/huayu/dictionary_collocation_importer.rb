# frozen_string_literal: true

module Huayu
  class DictionaryCollocationImporter
    SOURCE_SLUG = "moe_concised"
    HAN_ONLY = /\A\p{Han}+\z/

    def initialize(io: $stdout)
      @io = io
    end

    def call
      source = ContentSource.find_by!(slug: SOURCE_SLUG)
      texts = candidate_texts
      existing = Lexeme.where(text: texts).pluck(:text, :id, :kind)
      known = existing.to_h { |text, id, _kind| [text, id] }

      created = create_missing(texts - known.keys, source, known)
      linked = link_examples(known)
      attach_sources(source)

      @io.puts(format("dictionary collocations created : %6d", created))
      @io.puts(format("examples linked to lexemes  : %6d", linked))
      {created:, linked:}
    end

    private

    def candidate_texts
      SenseExample
        .collocation
        .distinct
        .pluck(:text)
        .map { |text| text.to_s.strip }
        .select { |text| text.match?(HAN_ONLY) && text.length >= 2 }
        .uniq
    end

    def create_missing(texts, source, known)
      now = Time.current
      created = 0

      texts.each_slice(1000) do |slice|
        rows = slice.map do |text|
          {
            kind: Lexeme.kinds[:collocation],
            text: text,
            readings: {},
            meanings: {},
            data: {"origin" => "moe_concised"},
            sources: ["MOE 簡編本"],
            created_at: now,
            updated_at: now
          }
        end

        result = Lexeme.insert_all(
          rows,
          unique_by: %i[kind text],
          returning: %w[id text]
        )
        result.each { |row| known[row["text"]] = row["id"] }
        created += result.length
      end

      created
    end

    def link_examples(known)
      linked = 0

      SenseExample.collocation.where(lexeme_id: nil).find_in_batches(batch_size: 1000) do |batch|
        batch.group_by { |example| known[example.text.to_s.strip] }.each do |lexeme_id, examples|
          next if lexeme_id.nil?

          SenseExample.where(id: examples.map(&:id)).update_all(lexeme_id: lexeme_id)
          linked += examples.length
        end
      end

      linked
    end

    def attach_sources(source)
      LexemeContentSource.connection.exec_update(
        <<~SQL,
          INSERT INTO lexeme_content_sources (lexeme_id, content_source_id, created_at)
          SELECT DISTINCT e.lexeme_id, #{source.id}, now()
          FROM sense_examples e
          JOIN lexemes l ON l.id = e.lexeme_id AND l.kind = #{Lexeme.kinds[:collocation]}
          WHERE e.lexeme_id IS NOT NULL
          ON CONFLICT DO NOTHING
        SQL
              "attach_dictionary_sources"
      )
    end
  end
end
