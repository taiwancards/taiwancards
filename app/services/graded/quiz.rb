# frozen_string_literal: true

module Graded
  class Quiz
    Exercise = Huayu::CourseLessons::Exercise
    MEANINGS = 2
    OPTIONS = 4
    PAIRS = 4
    CHUNKS = (3..7)
    ORDER_LENGTH = (6..16)

    def initialize(text, tokens:)
      @text = text
      @tokens = tokens
      @random = Random.new(Zlib.crc32(text.id))
    end

    def exercises
      @exercises ||= [*meanings, cloze, order, pair].compact.freeze
    end

    def size = exercises.size

    private

    def meanings
      @text.notes.first(MEANINGS).filter_map do |note|
        others = rival_notes(note).map(&:names)
        next if others.size < OPTIONS - 1

        options, answer = shuffled(note.names, others)
        build(kind: "meaning", zh: note.zh, options:, answer:)
      end
    end

    def cloze
      line, note = @text.lines.filter_map { |entry| (hit = blank_for(entry)) && [entry, hit] }.last
      return nil if note.nil?

      others = rival_notes(note).map(&:zh).reject { |zh| line.zh.include?(zh) }
      return nil if others.size < OPTIONS - 1

      options, answer = shuffled(note.zh, others)
      build(kind: "cloze", zh: line.zh.sub(note.zh, "＿＿"), gloss: line.names, options:, answer:)
    end

    def order
      line = @text.lines.reverse.find { |entry|
        ORDER_LENGTH.cover?(han_length(entry.zh)) && CHUNKS.cover?(chunks(entry).size)
      }
      return nil if line.nil?

      pieces = chunks(line)
      build(kind: "order", gloss: line.names, chunks: pieces, order: scrambled(pieces.size))
    end

    def pair
      lines = @text.lines.select { |entry| entry.names["en"].present? && entry.names["ru"].present? }
      return nil if lines.size < PAIRS

      step = lines.size.fdiv(PAIRS)
      picked = Array.new(PAIRS) { |index| lines[(index * step).floor] }
      pairs = picked.map { |entry| {"zh" => entry.zh, **entry.names} }
      build(kind: "pair", pairs:, order: scrambled(PAIRS))
    end

    def blank_for(line)
      once = @text.notes.select { |note| line.zh.scan(note.zh).size == 1 }
      once.drop(MEANINGS).first || once.first
    end

    def rival_notes(note)
      pool = Library.texts(@text.tier).reject { |other| other.id == @text.id }.flat_map(&:notes).uniq(&:zh)
      pool
        .reject { |other| other.zh == note.zh || other.zh.include?(note.zh) || note.zh.include?(other.zh) }
        .sample(OPTIONS - 1, random: @random)
    end

    def shuffled(right, wrong)
      options = [right, *wrong.first(OPTIONS - 1)].shuffle(random: @random)
      [options, options.index(right)]
    end

    def scrambled(count)
      order = (0...count).to_a
      order = order.shuffle(random: @random) while order == (0...count).to_a
      order
    end

    def chunks(line)
      Array(@tokens[line.zh]).reject { |token| token.kind == :literal }.map(&:text)
    end

    def han_length(text) = text.scan(/\p{Han}/).size

    def build(kind:, zh: nil, gloss: {}, options: [], answer: 0, chunks: [], order: [], pairs: [])
      Exercise.new(kind:, zh:, gloss:, options:, answer:, chunks:, order:, pairs:)
    end
  end
end
