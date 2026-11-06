# frozen_string_literal: true

module Huayu
  class LessonCharacters
    LIMIT = 6
    FAMILY = 4
    HAN = /\p{Han}/
    ETYMOLOGY_TEXT = EtymologyTranslations::KEY
    PHONO_SEMANTIC = "pictophonetic"
    GLOSS_BREAK = /[;；,，]/

    Entry = Data.define(:text, :zhuyin, :word, :meaning, :kind, :hint, :semantic, :semantic_gloss, :phonetic, :family)

    def initialize(lesson, lessons: CourseLessons.lessons, locale: I18n.locale)
      @lesson = lesson
      @lessons = lessons
      @locale = locale.to_s
    end

    def call
      debuts = debuting
      return [] if debuts.empty?

      chosen = Lexeme
        .where(kind: :character, text: debuts.keys)
        .select { |lexeme| lexeme.data["etymology"].present? }
        .min_by(LIMIT) { |lexeme| [lexeme.data["freq_rank"] || Float::INFINITY, debuts.keys.index(lexeme.text)] }
        .sort_by { |lexeme| debuts.keys.index(lexeme.text) }
      @parts = part_glosses(chosen)
      chosen.map { |lexeme| entry(lexeme, debuts[lexeme.text]) }
    end

    private

    def debuting
      met = @lessons.take_while { |other| other.slug != @lesson.slug }.flat_map(&:words).join.scan(HAN).to_set
      @lesson.vocabulary.each_with_object({}) do |word, found|
        word.zh.each_char.with_index do |char, index|
          next unless char.match?(HAN)
          next if met.include?(char) || found.key?(char)

          found[char] = {word: word.zh, zhuyin: syllable_at(word, index)}
        end
      end
    end

    def syllable_at(word, index)
      syllables = word.zhuyin.to_s.split(/[[:space:]]+/).reject(&:empty?)
      syllables[index] if syllables.size == word.zh.length
    end

    def part_glosses(lexemes)
      parts = lexemes.filter_map { |lexeme| lexeme.data.dig("etymology", "semantic").presence }.uniq
      return {} if parts.empty?

      Lexeme
        .where(kind: %i[character radical], text: parts)
        .order(:kind)
        .each_with_object({}) { |part, glosses|
          glosses[part.text] ||= part.meaning(@locale).to_s.split(GLOSS_BREAK).first&.strip.presence
        }
    end

    def entry(lexeme, debut)
      etymology = lexeme.data["etymology"]
      kind = etymology["type"].presence
      semantic = etymology["semantic"].presence
      phonetic = etymology["phonetic"].presence
      hint = hint(lexeme, etymology)
      phono_semantic = kind == PHONO_SEMANTIC && semantic
      Entry.new(
        text: lexeme.text,
        zhuyin: debut[:zhuyin] || lexeme.headline_zhuyin,
        word: (debut[:word] unless debut[:word] == lexeme.text),
        meaning: lexeme.meaning(@locale),
        kind:,
        hint: (hint unless phono_semantic),
        semantic:,
        semantic_gloss: (phono_semantic ? hint || @parts[semantic] : @parts[semantic]),
        phonetic:,
        family: family(lexeme.text, phonetic)
      )
    end

    def hint(lexeme, etymology)
      translated = lexeme.data.dig(ETYMOLOGY_TEXT, @locale, "hint").presence
      return translated if translated || @locale != Locales::DEFAULT

      etymology["hint"].presence
    end

    def family(char, phonetic)
      return [] if phonetic.nil?

      series = PhoneticSeries.for_component(phonetic)
      return [] unless series&.reliable?

      (series.members - [char]).first(FAMILY)
    end
  end
end
