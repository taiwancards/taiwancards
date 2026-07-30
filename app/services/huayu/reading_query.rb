# frozen_string_literal: true

module Huayu
  class ReadingQuery
    HAN = /\p{Han}/
    LATIN = /[a-zA-ZüÜêÊ#{Zhuyin::TONED_VOWELS.keys.join}]/
    TONE_DIGIT = /[1-5]/
    ZHUYIN_MARKS = "ˊˇˋ"
    NEUTRAL = "˙"
    TONE_BY_MARK = {"ˊ" => 2, "ˇ" => 3, "ˋ" => 4}.freeze
    MARK_BY_TONE = {1 => "", 2 => "ˊ", 3 => "ˇ", 4 => "ˋ"}.freeze
    ZHUYIN_ONLY = /\A[ㄅ-ㄯㆠ-ㆿˊˇˋ˙]+\z/
    PINYIN_ONLY = /\A[a-zêüv1-5]+\z/
    MAX_SYLLABLES = 8

    Syllable = Data.define(:pinyin, :zhuyin, :tone)

    Result = Data.define(:raw, :lower, :han, :syllables, :source) do
      def han? = han.present?

      def reading? = syllables.any?

      def tones = syllables.map(&:tone)

      def tones_given? = syllables.any? && syllables.all? { |syllable| syllable.tone }

      def tones_partial? = syllables.any?(&:tone) && syllables.any? { |syllable| syllable.tone.nil? }

      def pinyin_plain = syllables.map(&:pinyin).join.presence

      def zhuyin_plain = syllables.map(&:zhuyin).join.presence

      def pinyin_toned
        return nil unless tones_given?

        syllables.map { |syllable| "#{syllable.pinyin}#{syllable.tone}" }.join.presence
      end

      def zhuyin_toned
        return nil unless tones_given?

        syllables.map { |syllable| ReadingQuery.toned_zhuyin(syllable.zhuyin, syllable.tone) }.join.presence
      end

      def toned_tokens = [pinyin_toned, zhuyin_toned].compact_blank.uniq

      def plain_tokens = [pinyin_plain, zhuyin_plain].compact_blank.uniq

      def tokens = (toned_tokens + plain_tokens).uniq
    end

    class << self
      def call(query)
        new(query).call
      end

      def zhuyin_index
        @zhuyin_index ||= Zhuyin::SYLLABLES
          .filter_map { |syllable| [Zhuyin.syllable_to_zhuyin(syllable), syllable] }
          .reject { |zhuyin, _| zhuyin.nil? }
          .to_h
      end

      def zhuyin_keys
        @zhuyin_keys ||= zhuyin_index.keys.sort_by { |key| -key.length }
      end

      def toned_zhuyin(zhuyin, tone)
        return zhuyin.to_s if zhuyin.blank?
        return "#{NEUTRAL}#{zhuyin}" if tone.nil? || tone.to_i >= 5 || tone.to_i.zero?

        "#{zhuyin}#{MARK_BY_TONE.fetch(tone.to_i, "")}"
      end
    end

    def initialize(query)
      @raw = query.to_s.strip
    end

    def call
      Result.new(raw: @raw, lower: @raw.downcase, han: @raw.scan(HAN).join, syllables: parse, source: @source)
    end

    private

    def parse
      return none if @raw.empty?
      return none if @raw.match?(HAN)

      if ReadingForms.bopomofo?(@raw)
        @source = :zhuyin
        parse_zhuyin
      elsif @raw.match?(LATIN)
        @source = :pinyin
        parse_pinyin
      else
        none
      end
    end

    def none
      []
    end

    def parse_zhuyin
      text = @raw.gsub(/[[:space:]]+/, "")
      return none unless text.match?(ZHUYIN_ONLY)

      marked = text.match?(/[#{ZHUYIN_MARKS}#{NEUTRAL}]/o)
      chunks = split_zhuyin(text)
      return none if chunks.nil? || chunks.length > MAX_SYLLABLES

      chunks.map do |chunk|
        Syllable.new(
          pinyin: ReadingForms.plain_pinyin(chunk[:pinyin]),
          zhuyin: chunk[:zhuyin],
          tone: marked ? chunk[:tone] : nil
        )
      end
    end

    def split_zhuyin(text)
      keys = self.class.zhuyin_keys
      index = self.class.zhuyin_index
      result = []
      position = 0

      while position < text.length
        neutral = text[position] == NEUTRAL
        position += 1 if neutral
        match = keys.find { |key| text[position, key.length] == key }
        return nil if match.nil?

        position += match.length
        mark = text[position]
        tone = if neutral
          5
        elsif mark && TONE_BY_MARK.key?(mark)
          position += 1
          TONE_BY_MARK.fetch(mark)
        else
          1
        end

        result << {zhuyin: match, pinyin: index[match], tone: tone}
      end

      result
    end

    def parse_pinyin
      text = @raw.downcase.gsub(/[[:space:]'’·\-]/, "")
      return none if text.empty?
      return digit_pinyin(text) if text.match?(TONE_DIGIT)
      return marked_pinyin(text) if text.each_char.any? { |char| Zhuyin::TONED_VOWELS.key?(char) }

      bare_pinyin(text)
    end

    def digit_pinyin(text)
      return none unless text.match?(PINYIN_ONLY)

      groups = text.scan(/([a-zêüv]+)([1-5]?)/).reject { |letters, _| letters.empty? }
      return none if groups.empty?
      return none unless groups.sum { |letters, digit| letters.length + digit.to_s.length } == text.length

      built = groups.flat_map do |letters, digit|
        parts = split_pinyin(letters)
        return none if parts.nil?

        parts.each_with_index.map do |part, position|
          build_syllable(part, position == parts.length - 1 ? digit.presence&.to_i : nil)
        end
      end

      built.length > MAX_SYLLABLES ? none : built
    end

    def marked_pinyin(text)
      entries = Zhuyin.syllabify(text)
      return none if entries.nil? || entries.length > MAX_SYLLABLES

      entries.map do |entry|
        Syllable.new(
          pinyin: ReadingForms.plain_pinyin(entry["pinyin"]),
          zhuyin: ReadingForms.plain_zhuyin(entry["zhuyin"]),
          tone: Zhuyin.tone(entry["pinyin"])
        )
      end
    end

    def bare_pinyin(text)
      parts = split_pinyin(text)
      return none if parts.nil? || parts.length > MAX_SYLLABLES

      parts.map { |part| build_syllable(part, nil) }
    end

    def split_pinyin(letters)
      Zhuyin.segment(letters.tr("v", "ü")) || Zhuyin.segment(letters)
    end

    def build_syllable(part, tone)
      Syllable.new(pinyin: ReadingForms.plain_pinyin(part), zhuyin: Zhuyin.syllable_to_zhuyin(part), tone: tone)
    end
  end
end
