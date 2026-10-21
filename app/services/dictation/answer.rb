# frozen_string_literal: true

module Dictation
  class Answer
    Unit = Data.define(:char, :syllable, :tone, :typed) do
      def han? = !char.nil?
    end

    TOKEN = /(?<han>\p{Han})|(?<zhuyin>[ㄅ-ㄩˉˊˇˋ˙]+)|(?<latin>[[:alpha:]&&[^\p{Han}ㄅ-ㄩ]]+[0-5]?)/
    ZHUYIN_TONES = {"ˉ" => 1, "ˊ" => 2, "ˇ" => 3, "ˋ" => 4, "˙" => 5}.freeze
    LONGEST = 6
    ZHUYIN_INVENTORY = Huayu::Zhuyin::SYLLABLES
      .filter_map { |syllable| Huayu::Zhuyin.syllable_to_zhuyin(syllable) }
      .to_set
      .freeze
    PINYIN_INVENTORY = Huayu::Zhuyin::SYLLABLES.to_set.freeze
    VOWEL_START = /\A[aoeê]/

    def self.parse(text) = new(text).units

    def initialize(text)
      @text = text.to_s.unicode_normalize(:nfc)
    end

    def units
      marked = @text.match?(/[ˉˊˇˋ˙]/)
      @text.to_enum(:scan, TOKEN).flat_map do
        match = Regexp.last_match
        if match[:han]
          [Unit.new(char: match[:han], syllable: nil, tone: nil, typed: match[:han])]
        elsif match[:zhuyin]
          zhuyin_units(match[:zhuyin], marked)
        else
          pinyin_units(match[:latin])
        end
      end
    end

    private

    def zhuyin_units(run, marked)
      units = []
      letters = +""
      neutral_next = false
      close = lambda do |tone|
        pieces = split(letters, ZHUYIN_INVENTORY, orphans: false) || [letters]
        pieces.each_with_index do |piece, index|
          last = index == pieces.size - 1
          own = last ? tone : (marked ? 1 : nil)
          own = 5 if index.zero? && neutral_next
          units << zhuyin_unit(piece, own)
        end

        letters = +""
        neutral_next = false
      end

      chars = run.chars
      chars.each_with_index do |char, index|
        tone = ZHUYIN_TONES[char]
        if tone.nil?
          letters << char
        elsif tone == 5 && ZHUYIN_TONES[chars[index + 1]].nil? && index + 1 < chars.size
          close.call(marked ? 1 : nil) unless letters.empty?
          neutral_next = true
        elsif letters.empty?
          neutral_next = tone == 5
        else
          close.call(tone)
        end
      end

      close.call(marked ? 1 : nil) unless letters.empty?
      units
    end

    def zhuyin_unit(piece, tone)
      Unit.new(
        char: nil,
        syllable: piece,
        tone:,
        typed: "#{piece}#{ZHUYIN_TONES.key(tone) unless tone.nil? || tone == 1}"
      )
    end

    def pinyin_units(word)
      digit = word[/[0-5]\z/]&.to_i
      letters = word.delete_suffix(digit.to_s).downcase
      plain = +""
      marks = {}
      letters.each_char do |char|
        base, tone = Huayu::Zhuyin::TONED_VOWELS[char]
        marks[plain.length] = tone if base && tone.to_i.positive?
        plain << (base || char)
      end

      plain = plain.tr("v", "ü")

      pieces = split(plain, PINYIN_INVENTORY, orphans: true)
      return [Unit.new(char: nil, syllable: "?#{plain}", tone: nil, typed: word)] if pieces.nil?

      offset = 0
      pieces.each_with_index.map do |piece, index|
        range = offset...(offset + piece.length)
        offset += piece.length
        tone = marks.find { |position, _| range.cover?(position) }&.last
        tone = digit.zero? ? 5 : digit if digit && index == pieces.size - 1
        Unit.new(
          char: nil,
          syllable: Huayu::Zhuyin.syllable_to_zhuyin(piece),
          tone:,
          typed: "#{piece}#{tone}"
        )
      end
    end

    def split(plain, inventory, orphans:)
      return [] if plain.empty?

      best = Array.new(plain.length + 1)
      best[0] = [[0, 0], nil]
      (1..plain.length).each do |stop|
        ([stop - LONGEST, 0].max...stop).each do |start|
          next if best[start].nil?

          piece = plain[start...stop]
          next unless inventory.include?(piece)

          orphan = orphans && start.positive? && piece.match?(VOWEL_START) ? 1 : 0
          cost = [best[start][0][0] + orphan, best[start][0][1] + 1]
          best[stop] = [cost, start] if best[stop].nil? || (cost <=> best[stop][0]).negative?
        end
      end

      return nil if best[plain.length].nil?

      pieces = []
      stop = plain.length
      while stop.positive?
        start = best[stop][1]
        pieces.unshift(plain[start...stop])
        stop = start
      end

      pieces
    end
  end
end
