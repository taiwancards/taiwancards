# frozen_string_literal: true

module Search
  class Concordance
    POOL = 2000
    PER_PAGE = 10
    EXPANSION = 200

    Part = Data.define(:text, :hit)
    Row = Data.define(:lexeme, :profile, :parts)
    Result = Data.define(:rows, :total, :capped, :page, :pages, :per_page, :groups) do
      def any? = rows.any?

      def empty? = rows.empty?
    end

    EMPTY = Result.new(rows: [], total: 0, capped: false, page: 1, pages: 1, per_page: PER_PAGE, groups: [])

    def initialize(user:)
      @user = user
    end

    def call(groups:, registers: [], levels: {}, guaranteed: false, order: :easy, page: 1)
      groups = groups.reject(&:blank?).map { |group| Array(group).reject(&:blank?).uniq }.reject(&:empty?)
      return EMPTY if groups.empty?

      @needles = groups.flatten.uniq.sort_by { |text| -text.length }
      page = [page.to_i, 1].max
      found = slice(groups, registers, levels, guaranteed, order, page)
      return EMPTY.with(groups: groups) if found.empty?

      total = found.first["total"].to_i
      pages = [(total / PER_PAGE.to_f).ceil, 1].max
      if page > pages
        page = pages
        found = slice(groups, registers, levels, guaranteed, order, page)
      end

      Result.new(
        rows: rows_for(found.map { |row| row["id"] }),
        total: total,
        capped: total >= POOL,
        page: page,
        pages: pages,
        per_page: PER_PAGE,
        groups: groups
      )
    end

    def expand(text)
      return [] if text.blank?
      return [text] if text.length > 1

      words = Lexeme
        .where(kind: %i[word collocation])
        .where("lexemes.text LIKE ?", "%#{text}%")
        .frequency_order
        .limit(EXPANSION)
        .pluck(:text)

      ([text] + words).uniq
    end

    private

    ORDERS = {easy: "profiles.difficulty, profiles.lexeme_id", corpus: "profiles.lexeme_id"}.freeze

    def slice(groups, registers, levels, guaranteed, order, page)
      visible = ContentSource.visible_ids_for(@user)
      return [] if visible.empty?

      conditions = ["lexemes.kind = #{Lexeme.kinds[:sentence]}", "profiles.source_ids && ARRAY[:sources]::integer[]"]
      conditions << "lexemes.restricted = FALSE" unless @user&.restricted_access?
      binds = {sources: visible, offset: (page - 1) * PER_PAGE}

      groups.each_with_index do |group, index|
        conditions << "lexemes.data -> 'segments' ?| array[:g#{index}]"
        binds[:"g#{index}"] = group
      end

      if registers.any?
        conditions << "profiles.registers && ARRAY[:registers]::integer[]"
        binds[:registers] = registers.map { |name| ContentSource.registers[name] }.compact
      end

      SentenceProfile::SCHEMES.each do |scheme, config|
        position = config[:levels].index(levels[scheme].to_s)
        next if position.nil?

        conditions << "profiles.#{config[:index]} <= #{position + 1}"
        conditions << "profiles.#{config[:exact]} = TRUE" if guaranteed
      end

      sql = ActiveRecord::Base.sanitize_sql_array(
        [
          "WITH matches AS MATERIALIZED (" \
            "SELECT lexemes.id FROM lexemes JOIN sentence_profiles profiles ON profiles.lexeme_id = lexemes.id " \
            "WHERE #{conditions.join(" AND ")} LIMIT #{POOL}) " \
            "SELECT matches.id, count(*) OVER () AS total FROM matches " \
            "JOIN sentence_profiles profiles ON profiles.lexeme_id = matches.id " \
            "ORDER BY #{ORDERS.fetch(order.to_sym, ORDERS[:easy])} OFFSET :offset LIMIT #{PER_PAGE}",
          binds
        ]
      )

      ActiveRecord::Base.connection.select_all(sql).to_a
    end

    def rows_for(ids)
      profiles = SentenceProfile.where(lexeme_id: ids).index_by(&:lexeme_id)
      lexemes = Lexeme.where(id: ids).includes(:content_sources).index_by(&:id)

      ids.filter_map do |id|
        lexeme = lexemes[id]
        next if lexeme.nil?

        Row.new(lexeme: lexeme, profile: profiles[id], parts: highlight(lexeme.text))
      end
    end

    def highlight(text)
      parts = [Part.new(text: text, hit: false)]

      @needles.each do |needle|
        parts = parts.flat_map { |part| part.hit ? [part] : split_part(part.text, needle) }
      end

      parts.reject { |part| part.text.empty? }
    end

    def split_part(text, needle)
      pieces = text.split(needle, -1)
      return [Part.new(text: text, hit: false)] if pieces.length == 1

      result = []
      pieces.each_with_index do |piece, index|
        result << Part.new(text: piece, hit: false)
        result << Part.new(text: needle, hit: true) if index < pieces.length - 1
      end

      result
    end
  end
end
