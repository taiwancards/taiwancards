# frozen_string_literal: true

module Huayu
  class ToneQuiz
    OPTIONS = 4
    MAX_SYLLABLES = 4

    CONFUSABLE = {
      1 => [2, 4, 3],
      2 => [3, 1, 4],
      3 => [2, 4, 1],
      4 => [1, 3, 2],
      5 => [1, 4, 2]
    }.freeze

    Option = Data.define(:tones, :parts, :correct) do
      def zhuyin = parts.map { |part| part[:zhuyin] }.join(" ")

      def pinyin = parts.map { |part| part[:pinyin] }.join(" ")
    end

    def initialize(lexeme)
      @lexeme = lexeme
    end

    def call
      return [] unless available?

      correct = syllables.map { |part| tone_of(part) }
      variants = ([correct] + distractors(correct)).first(OPTIONS)
      return [] if variants.size < 2

      variants.sort_by { |tones| digest(tones) }.map { |tones| build(tones, tones == correct) }
    end

    def available?
      syllables.any? && syllables.size <= MAX_SYLLABLES && syllables.all? { |part| bare(part).present? }
    end

    private

    def syllables
      @syllables ||= Huayu::PronunciationTarget.new(@lexeme).syllables
    end

    def tone_of(part)
      value = part["tone"].to_i
      value.zero? ? 5 : value
    end

    def distractors(correct)
      (single_swaps(correct) + double_swaps(correct))
        .uniq
        .reject { |tones| tones == correct }
        .first(OPTIONS - 1)
    end

    def single_swaps(correct)
      by_position = correct.each_index.map do |index|
        CONFUSABLE.fetch(correct[index], []).map { |tone| correct.dup.tap { |out| out[index] = tone } }
      end

      by_position.first&.zip(*by_position.drop(1))&.flatten(1)&.compact || []
    end

    def double_swaps(correct)
      return [] if correct.size < 2

      first = CONFUSABLE.fetch(correct[0], []).first
      last = CONFUSABLE.fetch(correct[-1], []).first
      return [] if first.nil? || last.nil?

      [
        correct.dup.tap { |out|
          out[0] = first
          out[-1] = last
        }
      ]
    end

    def build(tones, correct)
      parts = syllables.each_with_index.map do |part, index|
        {
          zhuyin: Zhuyin.apply_tone(bare(part), tones[index]),
          pinyin: ReadingForms.marked_pinyin(part["pinyin"], tones[index])
        }
      end

      Option.new(tones:, parts:, correct:)
    end

    def bare(part)
      part["zhuyin"].to_s.gsub(/[#{ReadingForms::ZHUYIN_TONES}]/, "")
    end

    def digest(tones)
      Digest::MD5.hexdigest("#{@lexeme.id}:#{tones.join(",")}")
    end
  end
end
