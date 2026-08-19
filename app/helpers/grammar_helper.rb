# frozen_string_literal: true

module GrammarHelper
  HAN_RUN = /(\p{Han}+)/
  QUOTES = {"ru" => ["«", "»"], "en" => ["“", "”"]}.freeze
  ZH_RUN = /[\p{Han}][\p{Han}\p{Latin}0-9，、：；？！。…（）]*/
  GLOSS = /«[^»]+»|“[^”]+”|"[^"]+"/
  SEPARATOR = /\s*(?:[—–-]\s*)?/
  INLINE_MAX = 3
  CONTINUATION = /\A[[:lower:]]/
  SENTENCE_END = /(?<=[.!?？！。])\s+/
  STANDALONE_RUN = /\p{Han}(?:[\p{Han}，、：；]*\p{Han})?[？！。…]*/
  HAN = /\p{Han}/
  EXAMPLE_MIN = INLINE_MAX + 1
  EXAMPLE_LINE = /
    (?:(?<zh>#{ZH_RUN})#{SEPARATOR}(?<gloss>#{GLOSS}))
    |
    (?:(?<gloss>#{GLOSS})\s*[—–]\s*(?<zh>#{ZH_RUN}))
  /x

  PRACTICE = {"numbers" => :practice_numbers_path}.freeze
  HEAD_SINGLE = {1 => "text-3xl", 2 => "text-xl", 3 => "text-base", 4 => "text-sm"}.freeze
  HEAD_STACKED = {
    [2, 1] => "text-lg",
    [2, 2] => "text-sm",
    [3, 1] => "text-base",
    [3, 2] => "text-xs",
    [4, 1] => "text-xs"
  }.freeze
  HEAD_SMALLEST = "text-xs"

  Head = Data.define(:text, :zhuyin, :entry) do
    def meaning(locale) = entry&.meaning(locale).presence
  end

  def grammar_syllabus(lesson)
    return nil if lesson.supplementary?

    Huayu::TbclGrammar.find(lesson.id)
  end

  def grammar_practice_path(lesson)
    route = PRACTICE[lesson.slug]
    route && public_send(route)
  end

  def grammar_heads(lesson, entries: {})
    grammar_head_runs(lesson)
      .flat_map { |run| grammar_head_parts(run, entries) }
      .uniq
      .map { |part| Head.new(text: part, zhuyin: lesson.reading(part).to_h["zhuyin"], entry: entries[part]) }
  end

  def grammar_head_runs(lesson)
    lesson.head.to_s.scan(HAN_RUN).flatten.uniq
  end

  def grammar_prose(text, lesson, seen:, entries: {})
    return "" if text.blank?

    safe_join(
      grammar_blocks(text).map do |kind, first, second, note|
        if kind == :example
          grammar_example_line(first, second, note, lesson, seen, entries)
        else
          tag.p(grammar_run(first, lesson, seen, entries), class: "grammar-line")
        end
      end
    )
  end

  public def grammar_reading(run, lesson)
    reading = lesson.reading(run)
    zhuyin = reading.to_h["zhuyin"].presence
    pinyin = reading.to_h["pinyin"].presence
    return nil if zhuyin.nil? && pinyin.nil?

    tag.span(class: "reading") do
      safe_join(
        [
          (tag.span(zhuyin, class: "zy-reading", lang: "zh-TW") if zhuyin),
          (tag.span(pinyin, class: "py-reading", lang: "zh-Latn") if pinyin)
        ].compact
      )
    end
  end

  def grammar_example_text(example, entries)
    chunks = example.segments.presence || example.zh.chars

    tag.div(class: "zh-line flex-1", lang: "zh-TW") do
      safe_join(chunks.map { |chunk| entries[chunk] ? grammar_word_link(entries[chunk]) { chunk } : chunk })
    end
  end

  def grammar_example_reading(example)
    grammar_reading_lines(example.zhuyin, example.pinyin)
  end

  def grammar_reading_lines(zhuyin, pinyin)
    safe_join(
      [
        (tag.div(zhuyin, class: "zy-line", lang: "zh-TW") if zhuyin.present?),
        (tag.div(pinyin, class: "py-line", lang: "zh-Latn") if pinyin.present?)
      ].compact
    )
  end

  def grammar_quote(text, locale = I18n.locale)
    open, close = QUOTES.fetch(locale.to_s, QUOTES["en"])
    body = text.to_s.strip.sub(/\A[«"“]/, "").sub(/[»"”]\z/, "")
    tag.em("#{open}#{body}#{close}", class: "grammar-gloss")
  end

  def grammar_entries_for(lessons)
    lessons = Array(lessons)
    words = (lessons.flat_map { |lesson| lesson.examples.flat_map(&:segments) } +
      lessons.flat_map { |lesson| lesson.glossary.keys } +
      lessons.flat_map { |lesson| grammar_head_runs(lesson).flat_map { |run| grammar_substrings(run) } })
      .uniq
    return {} if words.empty?

    found = Lexeme.where(kind: %i[word collocation], text: words).index_by(&:text)
    singles = words.select { |word| word.length == 1 } - found.keys
    found.merge(Lexeme.where(kind: :character, text: singles).index_by(&:text))
  end

  def grammar_head_lines(lesson)
    parts = lesson.heads.presence || [lesson.head.to_s]
    return [parts, HEAD_SINGLE.fetch(parts.first.length, HEAD_SMALLEST)] if parts.one?

    [parts, HEAD_STACKED.fetch([parts.size, parts.map(&:length).max], HEAD_SMALLEST)]
  end

  def grammar_level_tabs(levels, selected)
    [[t("grammar.all_levels"), grammar_path, selected.nil?]] +
      levels.sort.map do |level|
        [t("grammar.level_label", level:), grammar_path(level:), selected == level]
      end
  end

  private

  def grammar_blocks(text)
    grammar_fold(grammar_split(text))
  end

  def grammar_fold(blocks)
    blocks.each_with_object([]) do |block, folded|
      previous = folded.last
      unless block.first == :prose && previous&.first == :example && block[1].match?(CONTINUATION)
        next folded << block
      end

      note, rest = block[1].split(SENTENCE_END, 2)
      previous[3] = [previous[3], note].compact_blank.join(" ")
      folded << [:prose, grammar_tidy(rest, false)] if rest.present?
    end
  end

  def grammar_split(text)
    blocks = []
    cursor = 0

    text.to_enum(:scan, EXAMPLE_LINE).each do
      match = Regexp.last_match
      next if match[:zh].scan(HAN).size < EXAMPLE_MIN

      prose = text[cursor...match.begin(0)]
      blocks.concat(grammar_prose_blocks(prose, blocks.empty?)) if prose.present?
      blocks << [:example, match[:zh], match[:gloss]]
      cursor = match.end(0)
    end

    rest = text[cursor..]
    blocks.concat(grammar_prose_blocks(rest, blocks.empty?)) if rest.present?
    blocks.reject { |kind, first, _| kind == :prose && first.blank? }
  end

  def grammar_prose_blocks(prose, first)
    blocks = []
    cursor = 0

    prose.to_enum(:scan, STANDALONE_RUN).each do
      match = Regexp.last_match
      next if match[0].scan(HAN).size < EXAMPLE_MIN

      before = prose[cursor...match.begin(0)]
      blocks << [:prose, grammar_tidy(before, first && blocks.empty?)] if before.present?
      blocks << [:example, match[0], nil]
      cursor = match.end(0)
    end

    rest = prose[cursor..]
    blocks << [:prose, grammar_tidy(rest, first && blocks.empty?)] if rest.present?
    blocks
  end

  def grammar_tidy(prose, first)
    prose = prose.sub(/\A[\s.,;:！。，、]+/, "") unless first
    prose.strip
  end

  def grammar_example_line(chinese, gloss, note, lesson, seen, entries)
    seen << chinese
    reading = (lesson.reading(chinese) || lesson.reading(chinese.gsub(/\P{Han}/, ""))).to_h

    tag.div(class: "grammar-example") do
      safe_join(
        [
          tag.div(chinese, class: "zh-line", lang: "zh-TW"),
          grammar_reading_lines(reading["zhuyin"], reading["pinyin"]),
          (tag.div(grammar_quote(gloss), class: "gloss-line") if gloss.present?),
          (tag.div(grammar_run(note, lesson, seen, entries), class: "note-line") if note.present?)
        ].compact
      )
    end
  end

  def grammar_run(text, lesson, seen, entries)
    safe_join(
      text.split(HAN_RUN).map do |chunk|
        next chunk unless chunk.match?(/\p{Han}/)

        grammar_term(chunk, lesson, seen, entries)
      end
    )
  end

  def grammar_term(run, lesson, seen, entries)
    body = entries[run] ? grammar_word_link(entries[run]) { run } : run
    reading = seen.add?(run) ? grammar_reading(run, lesson) : nil

    safe_join([tag.span(body, class: "zh-term", lang: "zh-TW"), reading].compact)
  end

  def grammar_substrings(run)
    (1..run.length).flat_map { |length| (0..run.length - length).map { |start| run[start, length] } }
  end

  def grammar_head_parts(run, entries)
    return [run] if entries[run]

    parts = []
    index = 0
    while index < run.length
      length = (run.length - index).downto(1).find { |size| entries[run[index, size]] }
      parts << run[index, length || 1]
      index += length || 1
    end

    parts
  end

  def grammar_word_link(entry, &)
    link_to(
      lexeme_page_path(entry),
      class: "hover:text-primary hover:underline underline-offset-4",
      title: entry.meaning(I18n.locale).presence,
      &
    )
  end
end
