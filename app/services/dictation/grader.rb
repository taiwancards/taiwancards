# frozen_string_literal: true

module Dictation
  class Grader
    MAX_ANSWER = 120
    CREDIT = {exact: 1.0, no_tone: 0.75, wrong_tone: 0.5, sound: 0.5}.freeze
    NEUTRAL = 5

    Target = Data.define(:char, :zhuyin, :syllable, :tones) do
      def neutral? = tones.include?(NEUTRAL)
    end

    Cell = Data.define(:char, :zhuyin, :mark, :typed) do
      def exact? = mark == :exact

      def missed? = mark.nil?
    end

    Result = Data.define(:cells, :percent, :answer, :extra) do
      def counts = cells.map(&:mark).tally
    end

    def initialize(text)
      @text = text.to_s
    end

    def call(answer)
      answer = answer.to_s.strip.first(MAX_ANSWER)
      units = Answer.parse(answer)
      @sounds = sounds_of(units.select(&:han?).map(&:char).uniq - targets.map(&:char))
      matches = align(units)
      cells = targets.each_with_index.map do |target, index|
        unit, mark = matches[index]
        Cell.new(char: target.char, zhuyin: target.zhuyin, mark:, typed: unit&.typed)
      end

      earned = cells.sum { |cell| CREDIT.fetch(cell.mark, 0) }
      total = [targets.size, units.size].max
      Result.new(
        cells:,
        percent: total.zero? ? 0 : (100 * earned / total).round,
        answer:,
        extra: units.size - matches.compact.size
      )
    end

    def sentence
      return @sentence if defined?(@sentence)

      @sentence = Lexeme.find_by(kind: :sentence, text: @text)
    end

    def targets
      @targets ||= rows.map do |row|
        Target.new(
          char: row["char"],
          zhuyin: row["zhuyin"],
          syllable: row["zhuyin"] && Huayu::ReadingForms.plain_zhuyin(row["zhuyin"]),
          tones: [row["tone"], row["base_tone"]].compact.uniq
        )
      end
    end

    private

    def rows
      found = sentence ? Huayu::PronunciationTarget.new(sentence).syllables : assembled
      return found if found.any?

      @text.scan(Huayu::TextReading::HAN).map { |char| {"char" => char} }
    end

    def assembled
      reading = Huayu::SentenceReadings.new.call([@text])[@text]&.pinyin
      Huayu::TextReading.rows(@text, reading)
    end

    def align(units)
      rows = targets.size
      columns = units.size
      best = Array.new(rows + 1) { Array.new(columns + 1, 0.0) }
      (1..rows).each do |i|
        (1..columns).each do |j|
          credit = CREDIT.fetch(mark_for(targets[i - 1], units[j - 1]), 0)
          best[i][j] = [best[i - 1][j], best[i][j - 1], (best[i - 1][j - 1] + credit if credit.positive?)].compact.max
        end
      end

      matches = Array.new(rows)
      i = rows
      j = columns
      while i.positive? && j.positive?
        mark = mark_for(targets[i - 1], units[j - 1])
        if mark && (best[i][j] - best[i - 1][j - 1] - CREDIT.fetch(mark)).abs < 1e-9
          matches[i - 1] = [units[j - 1], mark]
          i -= 1
          j -= 1
        elsif best[i][j] == best[i - 1][j]
          i -= 1
        else
          j -= 1
        end
      end

      matches
    end

    def mark_for(target, unit)
      return char_mark(target, unit.char) if unit.han?
      return nil unless target.syllable && target.syllable == unit.syllable
      return :exact if tone_right?(target, unit.tone)

      unit.tone.nil? ? :no_tone : :wrong_tone
    end

    def char_mark(target, char)
      return :exact if same_char?(target.char, char)
      return :sound if Huayu::SimpToTrad.options(char).include?(target.char)

      :sound if target.syllable && @sounds.fetch(char, []).include?(target.syllable)
    end

    def same_char?(expected, typed)
      expected == typed || Huayu::VariantForms::FORMS.fetch(expected, []).include?(typed)
    end

    def tone_right?(target, tone)
      return target.tones.include?(tone) unless target.neutral?

      tone.nil? || target.tones.include?(tone)
    end

    def sounds_of(chars)
      return {} if chars.empty?

      Lexeme
        .where(kind: :character, text: chars)
        .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |lexeme, found|
          lexeme.reading_set.each do |reading|
            found[lexeme.text] << Huayu::ReadingForms.plain_zhuyin(reading["zhuyin"]) if reading["zhuyin"].present?
          end
        end
    end
  end
end
