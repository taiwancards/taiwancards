# frozen_string_literal: true

require "csv"

module Lexemes
  class LevelExport
    HEADERS = %w[text zhuyin pinyin meaning_en meaning_ru tocfl_level tbcl_grade frequency_rank].freeze

    def initialize(scope, title:, origin:)
      @scope = scope
      @title = title
      @origin = origin
    end

    def to_csv
      notice = preamble.map { |line| "# #{line}".rstrip }.join("\n")
      body = CSV.generate do |csv|
        csv << HEADERS
        rows.each { |row| csv << row }
      end

      "#{notice}\n#{body}"
    end

    def preamble
      lines = [@title, "Exported from #{@origin}", ""].compact
      lines << "Sources and licences:"
      sources.each do |source|
        lines << "  #{source.name_en.presence || source.name} — #{source.license_name} #{source.license_url}".rstrip
        lines << "    #{source.attribution}" if source.attribution.present?
      end

      lines << ""
      lines << "Redistributed verbatim with attribution. Check each licence before reusing this file."
    end

    def sources
      ContentSource.where(id: source_ids).ordered
    end

    private

    def lexemes
      @lexemes ||= @scope.includes(:senses).to_a
    end

    def source_ids
      lexemes.flat_map { |lexeme| lexeme.senses.map(&:content_source_id) }.compact.uniq
    end

    def rows
      lexemes.map do |lexeme|
        [
          lexeme.text,
          lexeme.readings["zhuyin"],
          lexeme.readings["pinyin"],
          lexeme.meaning(:en),
          lexeme.meaning(:ru),
          lexeme.data["tocfl_level"],
          lexeme.data["tbcl_grade"],
          lexeme.freq_rank
        ]
      end
    end
  end
end
