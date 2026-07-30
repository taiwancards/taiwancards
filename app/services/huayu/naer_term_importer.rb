# frozen_string_literal: true

module Huayu
  class NaerTermImporter
    PATH = AppData.path("huayu/naer_terms.json")
    ATTRIBUTION = "國家教育研究院"
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
      return report(0, 0) unless @path.exist?

      rows = JSON.parse(@path.read)
      known = Lexeme.where(kind: %i[word collocation], text: rows.map { |row| row["text"] }).pluck(:text).to_set
      fresh = rows.reject { |row| known.include?(row["text"]) }

      created = insert(fresh)
      report(rows.length, created)
    rescue JSON::ParserError
      report(0, 0)
    end

    private

    def insert(rows)
      created = 0

      rows.each_slice(BATCH) do |slice|
        payload = slice.map { |row| attributes(row) }
        created += Lexeme.insert_all(payload, unique_by: %i[kind text], returning: false).rows.length
      end

      created
    end

    def attributes(row)
      now = Time.current
      {
        kind: Lexeme.kinds.fetch("word"),
        text: row["text"],
        readings: {},
        meanings: {"en" => row["en"]},
        data: {
          "origin" => "naer",
          "domain" => DOMAINS.fetch(row["domain"], row["domain"]),
          "tags" => Array(row["tags"]),
          "attribution" => ATTRIBUTION
        },
        sources: ["NAER terms"],
        created_at: now,
        updated_at: now
      }
    end

    def report(total, created)
      @io.puts(format("naer terms: %d read, %d added", total, created))
      {total:, created:}
    end
  end
end
