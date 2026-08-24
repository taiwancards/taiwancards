# frozen_string_literal: true

module Huayu
  class SentenceProfiler
    TOCFL_LEVELS = SentenceProfile::TOCFL_LEVELS
    FREQ_BANDS = SentenceProfile::FREQ_LIMITS

    APPROXIMATE_COVERAGE = 0.9
    MAX_UNKNOWN_FOR_APPROXIMATE = 2
    VOCABULARY_KEY = "profile_vocabulary"

    SQL_HAN = "[一-鿿㐀-䶿]"

    def self.stale
      Lexeme
        .where(kind: %i[sentence collocation])
        .joins("LEFT JOIN sentence_profiles profile ON profile.lexeme_id = lexemes.id")
        .where("lexemes.text ~ ?", SQL_HAN)
        .where("profile.lexeme_id IS NULL OR profile.difficulty IS DISTINCT FROM (lexemes.data ->> 'difficulty')::int")
    end

    def self.vocabulary_fingerprint
      kinds = %w[word character].map { |name| Lexeme.kinds.fetch(name) }.join(", ")

      Lexeme.connection.select_value(
        <<~SQL
          SELECT md5(string_agg(levels, ',' ORDER BY id))
          FROM (
            SELECT
              id,
              id::text || ':' ||
              coalesce(data ->> 'tocfl_level', '') || ':' ||
              coalesce(data ->> 'tbcl_grade', '') || ':' ||
              coalesce(data ->> 'freq_rank', '') AS levels
            FROM lexemes
            WHERE kind IN (#{kinds})
          ) graded
        SQL
      )
    end

    def self.vocabulary_drift? = Setting.instance.data[VOCABULARY_KEY] != vocabulary_fingerprint

    def self.remember_vocabulary!
      setting = Setting.instance
      setting.update!(data: setting.data.merge(VOCABULARY_KEY => vocabulary_fingerprint))
    end

    def initialize(io: $stdout, scope: nil)
      @io = io
      @scope = scope
      @analyzer = TextAnalyzer.new
    end

    def call
      load_vocabulary
      @sources = source_index

      composite.in_batches(of: BATCH) do |relation|
        rows = relation.pluck(:id, :text, :data, :kind)
        computed = ParallelMap.call(rows, warmup: method(:warm)) { |row| analyze(row) }.compact

        Bulk.upsert(
          target: "sentence_profiles",
          key: "lexeme_id",
          conflict: "lexeme_id",
          columns: PROFILE_COLUMNS,
          rows: computed
        )
      end

      report
    end

    private

    BATCH = 50_000

    PROFILE_COLUMNS = {
      "difficulty" => "integer",
      "han_length" => "integer",
      "tocfl_index" => "integer",
      "tocfl_exact" => "boolean",
      "tbcl_index" => "integer",
      "tbcl_exact" => "boolean",
      "freq_index" => "integer",
      "freq_exact" => "boolean",
      "unknown_count" => "integer",
      "registers" => "integer[]",
      "source_ids" => "integer[]",
      "created_at" => "timestamp",
      "updated_at" => "timestamp"
    }.freeze

    def composite = @scope || Lexeme.where(kind: %i[sentence collocation])

    def warm
      @analyzer.segment("暖機")
    end

    def source_index
      kinds = %w[sentence collocation].map { |name| Lexeme.kinds.fetch(name) }.join(", ")
      index = Hash.new { |memo, key| memo[key] = [[], []] }

      Lexeme
        .connection
        .select_rows(
          <<~SQL
            SELECT link.lexeme_id, link.content_source_id, source.register
            FROM lexeme_content_sources link
            JOIN content_sources source ON source.id = link.content_source_id
            JOIN lexemes owner ON owner.id = link.lexeme_id AND owner.kind IN (#{kinds})
            ORDER BY link.lexeme_id, link.content_source_id
          SQL
            .squish
        )
        .each do |lexeme_id, source_id, register|
          entry = index[lexeme_id.to_i]
          entry[0] << source_id.to_i
          entry[1] << register.to_i unless register.nil? || entry[1].include?(register.to_i)
        end

      index
    end

    def analyze(row)
      id, text, data, kind = row
      stored = data["segments"]
      units = if stored.is_a?(Array) && stored.any?
        stored
      else
        collocation = kind == Lexeme.kinds.fetch("collocation")
        @analyzer.segment(text, excluding: collocation ? text : nil)
      end

      return nil if units.empty?

      profile_row(id, text, data, units)
    end

    def profile_row(id, text, data, units)
      source_ids, registers = @sources[id]
      tocfl = scale(units, @tocfl, TOCFL_LEVELS.length)
      tbcl = scale(units, @tbcl, 7)
      freq = frequency_scale(units)
      now = Time.current

      [
        id,
        data["difficulty"].to_i,
        text.scan(/\p{Han}/).length,
        tocfl[:index],
        tocfl[:exact],
        tbcl[:index],
        tbcl[:exact],
        freq[:index],
        freq[:exact],
        [tocfl[:unknown], tbcl[:unknown], freq[:unknown]].max,
        registers,
        source_ids,
        now,
        now
      ]
    end

    def load_vocabulary
      @tocfl = {}
      @tbcl = {}
      @rank = {}

      Lexeme.where(kind: %i[word character]).pluck(:text, :data).each do |text, data|
        position = TOCFL_LEVELS.index(data["tocfl_level"])
        @tocfl[text] = position + 1 if position

        grade = data["tbcl_grade"]&.to_i
        @tbcl[text] = grade if grade&.positive?

        rank = data["freq_rank"]&.to_i
        @rank[text] = rank if rank&.positive?
      end
    end

    def scale(units, table, max_index)
      known = units.map { |unit| table[unit] }
      covered = known.compact
      return blank if covered.empty?

      unknown = known.count(&:nil?)
      coverage = covered.length.to_f / known.length
      return blank if too_thin?(unknown, coverage)

      {index: [covered.max, max_index].min, exact: unknown.zero?, unknown: unknown}
    end

    def frequency_scale(units)
      chars = units.join.chars.uniq
      ranks = chars.map { |char| @rank[char] }
      known = ranks.compact
      return blank if known.empty?

      unknown = ranks.count(&:nil?)
      coverage = known.length.to_f / ranks.length
      return blank if too_thin?(unknown, coverage)

      band = FREQ_BANDS.find { |limit| known.max <= limit }
      return blank if band.nil?

      {index: FREQ_BANDS.index(band) + 1, exact: unknown.zero?, unknown: unknown}
    end

    def too_thin?(unknown, coverage)
      return false if unknown.zero?

      coverage < APPROXIMATE_COVERAGE || unknown > MAX_UNKNOWN_FOR_APPROXIMATE
    end

    def blank
      {index: nil, exact: false, unknown: 0}
    end

    def report
      total = SentenceProfile.count
      @io.puts("rows with a profile: #{total}")
      SentenceProfile::SCHEMES.each_key do |scheme|
        config = SentenceProfile::SCHEMES.fetch(scheme)
        placed = SentenceProfile.where.not(config[:index] => nil).count
        exact = SentenceProfile.where(config[:exact] => true).count
        @io.puts(
          format("  %-6s placed %6d, exact %6d", scheme, placed, exact)
        )
      end
    end
  end
end
