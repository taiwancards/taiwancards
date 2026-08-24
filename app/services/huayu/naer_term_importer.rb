# frozen_string_literal: true

module Huayu
  class NaerTermImporter
    PATH = AppData.path("huayu/naer_terms.json")
    ATTRIBUTION = "國家教育研究院"
    SOURCE = "NAER terms"
    DOMAINS = {
      "signage" => "places",
      "counters" => "admin",
      "culture" => "food",
      "elections" => "civics",
      "titles" => "work"
    }.freeze
    BATCH = 1_000

    def initialize(io: $stdout, path: PATH)
      @io = io
      @path = path
    end

    def call
      return report(0, 0, 0) unless @path.exist?

      rows = JSON.parse(@path.read)
      rows.each { |row| row["text"] = row["text"].to_s.tr("体", "體") }
      texts = rows.map { |row| row["text"] }

      mine = Lexeme.where(kind: :word, text: texts).where("sources @> ?", [SOURCE].to_json).index_by(&:text)
      taken = Lexeme.where(kind: %i[word collocation], text: texts).pluck(:text).to_set

      created = insert(rows.reject { |row| taken.include?(row["text"]) })
      updated = refresh(rows, mine)
      TextAnalyzer.reset_vocabulary! if created.positive?
      report(rows.length, created, updated)
    rescue JSON::ParserError
      report(0, 0, 0)
    end

    private

    def insert(rows)
      created = 0

      rows.each_slice(BATCH) do |slice|
        payload = slice.map { |row| attributes(row).merge(created_at: Time.current, updated_at: Time.current) }
        created += Lexeme.insert_all(payload, unique_by: %i[kind text], returning: %w[id]).rows.length
      end

      created
    end

    def refresh(rows, mine)
      updated = 0

      rows.each do |row|
        lexeme = mine[row["text"]]
        next unless lexeme

        payload = changes(lexeme, row)
        next if payload.empty?

        lexeme.update_columns(payload.merge(updated_at: Time.current))
        updated += 1
      end

      updated
    end

    def changes(lexeme, row)
      fresh = attributes(row)
      data = lexeme.data.merge(fresh[:data])
      data = data.except("origin") if data["origin"] == "naer"

      payload = {readings: fresh[:readings], meanings: fresh[:meanings], data: data}
      payload.reject { |column, value| lexeme.public_send(column) == value }
    end

    def attributes(row)
      {
        kind: Lexeme.kinds.fetch("word"),
        text: row["text"],
        readings: {"pinyin" => row["pinyin"], "zhuyin" => row["zhuyin"]}.compact_blank,
        meanings: {"en" => row["en"], "ru" => row["ru"]}.compact_blank,
        data: {
          "domain" => DOMAINS.fetch(row["domain"], row["domain"]),
          "tags" => Array(row["tags"]),
          "attribution" => ATTRIBUTION
        },
        sources: [SOURCE]
      }
    end

    def report(total, created, updated)
      @io.puts(format("naer terms: %d read, %d added, %d refreshed", total, created, updated))
      {total:, created:, updated:}
    end
  end
end
