# frozen_string_literal: true

module Huayu
  class SentenceProfiler
    TOCFL_LEVELS = SentenceProfile::TOCFL_LEVELS
    FREQ_BANDS = SentenceProfile::FREQ_LIMITS

    APPROXIMATE_COVERAGE = 0.9
    MAX_UNKNOWN_FOR_APPROXIMATE = 2

    SQL_HAN = "[一-鿿㐀-䶿]"

    def self.stale
      Lexeme
        .where(kind: %i[sentence collocation])
        .joins("LEFT JOIN sentence_profiles profile ON profile.lexeme_id = lexemes.id")
        .where("lexemes.text ~ ?", SQL_HAN)
        .where("profile.lexeme_id IS NULL OR profile.difficulty IS DISTINCT FROM (lexemes.data ->> 'difficulty')::int")
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
          rows: computed.map(&:first)
        )
        Bulk.patch(target: "lexemes", columns: THRESHOLD_TYPES, rows: computed.map(&:last))
      end

      atomic_thresholds if @scope.nil?
      report
    end

    private

    BATCH = 50_000
    THRESHOLD_COLUMNS = LevelThresholds::SCALES.flat_map { |scale| LevelThresholds.columns_for(scale) }.freeze
    THRESHOLD_TYPES = THRESHOLD_COLUMNS.to_h { |column| [column.to_s, "smallint"] }.freeze

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
      thresholds
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

      [profile_row(id, text, data, units), threshold_row(id, units)]
    end

    def threshold_row(id, units)
      values = LevelThresholds::SCALES.reduce({}) { |memo, scale| memo.merge(thresholds.for_tokens(scale, units)) }
      [id, *THRESHOLD_COLUMNS.map { |column| values.fetch(column) }]
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

    def atomic_thresholds
      rows = Lexeme
        .where(kind: %i[word character measure_word])
        .pluck(:id, :data)
        .map do |id, data|
          tbcl = data["tbcl_grade"]&.to_i
          tocfl = TOCFL_LEVELS.index(data["tocfl_level"])
          values = thresholds
            .for_level("tbcl", tbcl&.positive? ? tbcl : nil)
            .merge(thresholds.for_level("tocfl", tocfl ? tocfl + 1 : nil))

          [id, *THRESHOLD_COLUMNS.map { |column| values.fetch(column) }]
        end

      Bulk.patch(target: "lexemes", columns: THRESHOLD_TYPES, rows: rows)
    end

    def thresholds = @thresholds ||= LevelThresholds.instance

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
