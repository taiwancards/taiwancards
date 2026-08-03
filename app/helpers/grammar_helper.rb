# frozen_string_literal: true

module GrammarHelper
  HAN_RUN = /(\p{Han}+)/

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

  def grammar_prose(text, lesson, entries: {})
    return "" if text.blank?

    safe_join(
      text.split(HAN_RUN).map do |chunk|
        chunk.match?(/\p{Han}/) ? grammar_term(chunk, lesson, entries) : chunk
      end
    )
  end

  def grammar_term(run, lesson, entries = {})
    reading = lesson.reading(run)
    body = grammar_term_body(run, reading)
    body = grammar_word_link(entries[run]) { body } if entries[run]

    tag.span(body, class: "zh-term zy-run zy-top", lang: "zh-TW")
  end

  def grammar_example_ruby(example, entries: {}, css: nil)
    queue = example.syllables.dup

    tag.span(lang: "zh-TW", class: class_names("zy-run", grammar_zhuyin_run_class, css)) do
      safe_join(grammar_example_chunks(example).map { |chunk| grammar_chunk(chunk, queue, entries) })
    end
  end

  def grammar_example_plain(example, entries: {})
    tag.span(lang: "zh-TW") do
      safe_join(
        grammar_example_chunks(example).map do |chunk|
          entry = entries[chunk]
          entry ? grammar_word_link(entry) { chunk } : tag.span(chunk)
        end
      )
    end
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

  def grammar_zhuyin_run_class
    zhuyin_position_for(:body) == "over" ? "zy-over" : "zy-right"
  end

  private

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

  def grammar_term_body(run, reading)
    syllables = reading.to_h["zhuyin"].to_s.split(/[[:space:]]+/).reject(&:empty?)
    return run unless syllables.size == run.length

    safe_join(run.chars.zip(syllables).map { |char, syllable| zhuyin_ruby_pair(char, syllable) })
  end

  def grammar_example_chunks(example)
    return example.segments if example.segments.present?

    example.zh.chars
  end

  def grammar_chunk(chunk, queue, entries)
    body = safe_join(
      chunk.chars.map do |char|
        char.match?(/\p{Han}/) && queue.any? ? zhuyin_ruby_pair(char, queue.shift) : tag.span(char)
      end
    )
    entry = entries[chunk]
    entry ? grammar_word_link(entry) { body } : body
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
