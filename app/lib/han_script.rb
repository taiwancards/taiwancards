# frozen_string_literal: true

module HanScript
  TABLE = JsonData.new(
    "huayu/japanese_script.json",
    default: {"japanese" => "", "japanese_only" => "", "differs" => ""}
  )
  OPEN = "〘"
  CLOSE = "〙"
  MARKERS = /[#{OPEN}#{CLOSE}]/
  MARKED = /#{OPEN}([^#{OPEN}#{CLOSE}]*)#{CLOSE}/
  TONES = "ˊˇˋ˙"
  RUN = /[\p{Han}\p{Bopomofo}#{TONES}]+/
  SCRIPT = /[\p{Han}\p{Bopomofo}#{OPEN}]/
  HAN = /\p{Han}/
  BOPOMOFO = /[\p{Bopomofo}#{TONES}]/
  KANA = /[\p{Hiragana}\p{Katakana}]/
  FOREIGN = /[\p{Latin}\p{Cyrillic}]/
  GLUE = /\A[，、；：？！。…]+\z/
  CLOSING = /\A[。？！…]+/
  SENTENCE = 4

  Parsed = Data.define(:text, :ranges) do
    def mandarin?(range) = ranges.any? { |span| span.cover?(range.begin) && span.cover?(range.end - 1) }

    def pieces
      cursor = 0
      parts = ranges.flat_map do |range|
        before = text[cursor...range.begin]
        cursor = range.end
        [[before, false], [text[range], true]]
      end

      (parts << [text[cursor..], false]).reject { |piece, _| piece.empty? }
    end
  end

  module_function

  def parse(text, locale = I18n.locale, context: nil)
    locale = Locales::DEFAULT if [text, context].any?(Locales::Fallback)
    text = text.to_s
    return Parsed.new(text:, ranges: []) unless text.match?(SCRIPT) || text.include?(CLOSE)

    plain, marked = unmark(text)
    foreign = foreign?(context || plain)
    runs = plain.to_enum(:scan, RUN).map { Regexp.last_match.then { |match| match.begin(0)...match.end(0) } }
    found = runs.reject { |range| covered?(marked, range) }.select { |range|
      mandarin?(plain[range], locale, foreign:)
    }
    Parsed.new(text: plain, ranges: joined(plain, (marked + found).sort_by(&:begin)))
  end

  def spans(text, locale = I18n.locale) = parse(text, locale).ranges

  def plain(text) = text.to_s.gsub(MARKERS, "")

  def mandarin?(run, locale = I18n.locale, foreign: false)
    return true unless Locales.writes_han?(locale)
    return true if run.match?(BOPOMOFO)
    return true if run.each_char.any? { |char| differs.include?(char) }

    foreign && run.each_char.none? { |char| japanese_only.include?(char) }
  end

  def mandarin_piece?(piece, locale = I18n.locale, context: nil)
    parsed = parse(piece, locale, context:)
    parsed.text.to_enum(:scan, /\p{Han}+/).all? do
      match = Regexp.last_match
      parsed.mandarin?(match.begin(0)...match.end(0))
    end
  end

  def foreign?(text) = !text.match?(KANA) && text.match?(FOREIGN)

  def japanese = table[:japanese]

  def japanese_only = table[:japanese_only]

  def differs = table[:differs]

  def reset!
    @table = nil
    TABLE.reset!
  end

  def table
    raw = TABLE.value
    return @table if @table && @table_from.equal?(raw)

    @table_from = raw
    @table = %w[japanese japanese_only differs].to_h { |name| [name.to_sym, raw[name].to_s.chars.to_set] }
  end

  def unmark(text)
    plain = +""
    marked = []
    cursor = 0
    text.to_enum(:scan, MARKED).each do
      match = Regexp.last_match
      plain << text[cursor...match.begin(0)].gsub(MARKERS, "")
      marked << (plain.length...(plain.length + match[1].length)) unless match[1].empty?
      plain << match[1]
      cursor = match.end(0)
    end

    plain << text[cursor..].to_s.gsub(MARKERS, "")
    [plain, marked]
  end

  def covered?(spans, range) = spans.any? { |span| span.cover?(range.begin) && span.cover?(range.end - 1) }

  def joined(text, ranges)
    ranges
      .each_with_object([]) do |range, merged|
        previous = merged.last
        if previous && range.begin <= previous.end
          merged[-1] = previous.begin...[previous.end, range.end].max
        elsif previous && text[previous.end...range.begin].match?(GLUE)
          merged[-1] = previous.begin...range.end
        else
          merged << range
        end
      end
      .map { |range| closed(text, range) }
  end

  def closed(text, range)
    return range if text[range].scan(HAN).size < SENTENCE

    tail = text[range.end..].to_s[CLOSING]
    tail ? range.begin...(range.end + tail.length) : range
  end
end
