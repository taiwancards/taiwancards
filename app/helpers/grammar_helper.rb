# frozen_string_literal: true

module GrammarHelper
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
    words = Array(lessons).flat_map { |lesson| lesson.examples.flat_map(&:segments) }.uniq
    return {} if words.empty?

    found = Lexeme.where(kind: %i[word collocation], text: words).index_by(&:text)
    singles = words.select { |word| word.length == 1 } - found.keys
    found.merge(Lexeme.where(kind: :character, text: singles).index_by(&:text))
  end

  def grammar_zhuyin_run_class
    zhuyin_position_for(:body) == "over" ? "zy-over" : "zy-right"
  end

  private

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
