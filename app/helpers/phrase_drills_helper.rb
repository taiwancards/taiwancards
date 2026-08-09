# frozen_string_literal: true

module PhraseDrillsHelper
  def drill_token_zhuyin(token)
    reading = token.lexeme&.reading_set&.first&.dig("zhuyin").presence
    reading ||= token.chars.filter_map { |char| char.reading_set.first&.dig("zhuyin").presence }.join(" ").presence
    reading if reading && reading.split(/[[:space:]]+/).size == token.text.scan(/\p{Han}/).size
  end

  def drill_pinyin(tokens)
    tokens
      .filter_map do |token|
        next if token.kind == :literal

        token.lexeme&.reading_set&.first&.dig("pinyin").presence ||
          token.chars.filter_map { |char| char.reading_set.first&.dig("pinyin").presence }.join.presence
      end
      .join(" ")
  end

  def drill_level(lexeme)
    difficulty = lexeme.data["difficulty"].to_i
    (difficulty / PhraseDrillsController::LEVEL_SPAN).clamp(0, 4) + 1
  end

  def drill_book(lexeme)
    lexeme.data.key?("drill") ? "GL" : "DA"
  end

  def grade_options(scheme = nil)
    PhraseDrillsController::SCHEMES.flat_map do |name|
      next [] if scheme && scheme != name

      SentenceProfile::SCHEMES.fetch(name)[:levels].each_with_index.map do |label, index|
        [label, (index + 1).to_s, {data: {scheme: name}}]
      end
    end
  end

  def drill_grade(lexeme, scheme)
    index = lexeme.data[scheme]
    return nil if index.nil?

    label = SentenceProfile::SCHEMES.fetch(scheme)[:levels][index.to_i - 1]
    return nil if label.nil?

    lexeme.data["#{scheme}_exact"] ? label : "#{label}*"
  end
end
