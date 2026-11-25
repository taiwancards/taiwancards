# frozen_string_literal: true

module Scans
  module TextFilter
    MAX_LINES = 150
    MAX_LINE = 200
    MAX_CHARS = 4000
    MANDARIN = /[\p{Han}\p{Bopomofo}]/
    MANDARIN_MARKS = "\\p{Han}\\p{Bopomofo}　-〿！-～｡-･ˇˊˋ˙"
    COMPANIONS = "\\p{Latin}\\p{Nd} -~°·–—‘’“”•…‧※℃□"
    DROPPED = Regexp.new("[^#{MANDARIN_MARKS}#{COMPANIONS}]")

    module_function

    def call(lines)
      kept = Array(lines).first(MAX_LINES * 2).filter_map { |line| clean(line) }
      fit(kept.first(MAX_LINES)).join("\n")
    end

    def clean(line)
      return unless line.is_a?(String)

      text = line.unicode_normalize(:nfc).gsub(/[[:space:]]+/, " ").gsub(DROPPED, "").squeeze(" ").strip
      text.first(MAX_LINE) if text.match?(MANDARIN)
    end

    def fit(lines)
      room = MAX_CHARS
      lines.each_with_object([]) do |line, kept|
        break kept if room <= 0

        kept << line.first(room)
        room -= line.length + 1
      end
    end
  end
end
