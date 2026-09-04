# frozen_string_literal: true

module Huayu
  class SchoolLevelImporter
    PATH = AppData.path("huayu/school_levels.json")
    HAN = /\A\p{Han}+\z/

    def initialize(path: PATH)
      @path = Pathname(path)
    end

    def call
      return {error: "missing #{@path}"} unless @path.exist?

      counts = Hash.new(0)
      JSON.parse(@path.read).each do |row|
        text = row["traditional"].to_s.strip
        next if text.blank? || !text.match?(HAN)

        grade = row["level"].to_s[/第(\d)/, 1]&.to_i
        band = row["level"].to_s[/\A(\p{Han}+)/, 1]
        kind = (row["source"] == "hanzi" || text.length == 1) ? :character : :word

        lexeme = Lexeme.find_or_initialize_by(kind: Lexeme.kinds[kind], text:)
        created = lexeme.new_record?

        if row["pinyin"].present? && replace_reading?(lexeme.readings["pinyin"], row["pinyin"])
          lexeme.readings = lexeme
            .readings
            .merge(
              "pinyin" => row["pinyin"],
              "zhuyin" => Huayu::Zhuyin.from_pinyin(row["pinyin"])
            )
            .compact_blank
        end

        lexeme.data = lexeme
          .data
          .merge("tbcl_grade" => grade, "tbcl_band" => band, "tbcl_level" => row["level"])
          .compact
        lexeme.add_source("TBCL #{grade}")
        lexeme.save! if lexeme.changed?

        counts[created ? :created : :updated] += 1
        counts[:"grade_#{grade}"] += 1 if grade
      end

      counts
    end

    private

    def replace_reading?(current, fresh)
      return true if current.blank?

      plain = -> (value) { value.to_s.unicode_normalize(:nfd).gsub(/[^a-z]/i, "") }
      truncated = plain.call(current)
      truncated.present? && truncated != plain.call(fresh) && plain.call(fresh).start_with?(truncated)
    end
  end
end
