# frozen_string_literal: true

module GrammarHelper
  HAN_RUN = /(\p{Han}+)/
  ZHUYIN_DEFAULT_THROUGH = 2
  QUOTES = {"ru" => ["«", "»"], "en" => ["“", "”"]}.freeze
  ZH_RUN = /[\p{Han}][\p{Han}\p{Latin}0-9，、：；？！。…（）]*/
  GLOSS = /«[^»]+»|“[^”]+”|"[^"]+"/
  EXAMPLE_LINE = /
    (?:(?<zh>#{ZH_RUN})\s*[—–]\s*(?<gloss>#{GLOSS}))
    |
    (?:(?<gloss>#{GLOSS})\s*[—–]\s*(?<zh>#{ZH_RUN}))
  /x

  PRACTICE = {"numbers" => :practice_numbers_path}.freeze

  Head = Data.define(:text, :zhuyin, :entry) do
    def meaning(locale) = entry&.meaning(locale).presence
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

  def grammar_zhuyin_default?(lesson) = lesson.level <= ZHUYIN_DEFAULT_THROUGH

  def grammar_prose(text, lesson, seen:, entries: {})
    return "" if text.blank?

    safe_join(
      grammar_blocks(text).map do |kind, first, second|
        if kind == :example
          grammar_example_line(first, second, lesson, seen)
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
          (tag.span(pinyin, class: "pinyin py-reading", lang: "zh-Latn") if pinyin)
        ].compact
      )
    end
  end

  def grammar_example_text(example, entries)
    chunks = example.segments.presence || example.zh.chars

    tag.span(class: "zh-line", lang: "zh-TW") do
      safe_join(chunks.map { |chunk| entries[chunk] ? grammar_word_link(entries[chunk]) { chunk } : chunk })
    end
  end

  def grammar_example_reading(example)
    zhuyin = example.zhuyin.presence
    pinyin = example.pinyin.presence
    return nil if zhuyin.nil? && pinyin.nil?

    tag.span(class: "reading") do
      safe_join(
        [
          (tag.span(zhuyin, class: "zy-reading", lang: "zh-TW") if zhuyin),
          (tag.span(pinyin, class: "pinyin py-reading", lang: "zh-Latn") if pinyin)
        ].compact
      )
    end
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

  def grammar_level_tabs(levels, selected)
    [[t("grammar.all_levels"), grammar_path, selected.nil?]] +
      levels.sort.map do |level|
        [t("grammar.level_label", level:), grammar_path(level:), selected == level]
      end
  end

  private

  def grammar_blocks(text)
    blocks = []
    cursor = 0

    text.to_enum(:scan, EXAMPLE_LINE).each do
      match = Regexp.last_match
      prose = text[cursor...match.begin(0)]
      blocks << [:prose, grammar_tidy(prose, blocks.empty?)] if prose.present?
      blocks << [:example, match[:zh], match[:gloss]]
      cursor = match.end(0)
    end

    rest = text[cursor..]
    blocks << [:prose, grammar_tidy(rest, blocks.empty?)] if rest.present?
    blocks.reject { |kind, first, _| kind == :prose && first.blank? }
  end

  def grammar_tidy(prose, first)
    prose = prose.sub(/\A[\s.,;:！。，、]+/, "") unless first
    prose.strip
  end

  def grammar_example_line(chinese, gloss, lesson, seen)
    reading = grammar_reading(chinese, lesson)
    seen << chinese

    tag.p(class: "grammar-example") do
      safe_join([tag.span(chinese, class: "zh-line", lang: "zh-TW"), reading, grammar_quote(gloss)].compact)
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
