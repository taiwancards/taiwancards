# frozen_string_literal: true

module Huayu
  class CourseExplainer
    NOISE = /[\p{P}\s]/
    SENTENCE_KINDS = %w[cloze reply order].freeze
    WORD_KINDS = %w[meaning word reading].freeze

    Explanation = Data.define(:kind, :zh, :reading, :body, :detail, :grammar)

    def initialize(lessons)
      @lessons = Array(lessons)
    end

    def call(exercise, locale)
      case exercise.kind
      when *WORD_KINDS
        word_note(word_of(exercise), locale)
      when "street"
        street_note(exercise, locale)
      when *SENTENCE_KINDS
        sentence_note(exercise, locale)
      end
    end

    private

    def word_of(exercise)
      exercise.kind == "meaning" ? exercise.zh : exercise.right_option
    end

    def word_note(text, locale)
      word = words[text]
      return nil if word.nil?

      Explanation.new(
        kind: :word,
        zh: word.zh,
        reading: [word.zhuyin, word.pinyin].compact_blank.join(" · "),
        body: word.gloss(locale),
        detail: word.note_for(locale),
        grammar: nil
      )
    end

    def street_note(exercise, locale)
      said = exercise.right_option
      usage = usages.find { |entry| entry.street == said || entry.standard == exercise.zh }
      return nil if usage.nil?

      Explanation.new(
        kind: :usage,
        zh: "#{usage.standard} → #{usage.street}",
        reading: nil,
        body: usage.body(locale),
        detail: nil,
        grammar: nil
      )
    end

    def sentence_note(exercise, locale)
      grammar_note(sentences_of(exercise), locale) ||
        (word_note(exercise.right_option, locale) if exercise.kind == "cloze")
    end

    def sentences_of(exercise)
      case exercise.kind
      when "cloze"
        [exercise.zh.to_s.sub("＿＿", exercise.right_option.to_s)]
      when "reply"
        [exercise.right_option, exercise.zh]
      else
        [Array(exercise.chunks).join]
      end
    end

    def grammar_note(sentences, locale)
      sentences.each do |sentence|
        lesson, line = lines[normalize(sentence)]
        next if line.nil?

        line.grammar.each do |slug|
          ref = lesson.grammar_ref(slug)
          note = ref&.note_for(locale)
          if note.present?
            return Explanation.new(kind: :grammar, zh: nil, reading: nil, body: note, detail: nil, grammar: ref.lesson)
          end
        end
      end

      nil
    end

    def normalize(text) = text.to_s.gsub(NOISE, "")

    def words
      @words ||= @lessons.flat_map(&:vocabulary).reverse.index_by(&:zh)
    end

    def usages
      @usages ||= @lessons.flat_map(&:usage)
    end

    def lines
      @lines ||= @lessons
        .flat_map { |lesson| lesson.lines.map { |line| [normalize(line.zh), [lesson, line]] } }
        .reverse
        .to_h
    end
  end
end
