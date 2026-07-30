# frozen_string_literal: true

module Huayu
  class NumberDrill
    STAGES = %w[glyphs myriads reading traps taiwan].freeze
    CHOICES = 4
    ROC_OFFSET = 1911

    GLYPHS = [
      {text: "零", pinyin: "líng", value: "0"},
      {text: "一", pinyin: "yī", value: "1"},
      {text: "二", pinyin: "èr", value: "2"},
      {text: "三", pinyin: "sān", value: "3"},
      {text: "四", pinyin: "sì", value: "4"},
      {text: "五", pinyin: "wǔ", value: "5"},
      {text: "六", pinyin: "liù", value: "6"},
      {text: "七", pinyin: "qī", value: "7"},
      {text: "八", pinyin: "bā", value: "8"},
      {text: "九", pinyin: "jiǔ", value: "9"},
      {text: "十", pinyin: "shí", value: "10"},
      {text: "百", pinyin: "bǎi", value: "100"},
      {text: "千", pinyin: "qiān", value: "1000"},
      {text: "萬", pinyin: "wàn", value: "10000"},
      {text: "億", pinyin: "yì", value: "100000000"},
      {text: "兆", pinyin: "zhào", value: "1000000000000"},
      {text: "兩", pinyin: "liǎng", value: "2"}
    ].freeze

    MYRIAD_ANCHORS = [10_000, 100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000].freeze

    TRAPS = [200, 2000, 20_000, 105, 1005, 1050, 10_005, 110, 115, 15, 1_250, 100_050_000].freeze

    def initialize(seed: nil)
      @rng = Random.new(seed || Random.new_seed)
    end

    def items(stage, count: 12)
      case stage
      when "glyphs"
        glyph_items(count)
      when "myriads"
        myriad_items(count)
      when "traps"
        trap_items(count)
      when "taiwan"
        roc_items(count)
      else
        reading_items(count)
      end
    end

    private

    attr_reader :rng

    def glyph_items(count)
      GLYPHS.sample(count, random: rng).map { |glyph|
        others = (GLYPHS - [glyph]).sample(CHOICES - 1, random: rng)
        build(
          id: "glyph:#{glyph[:text]}",
          prompt: glyph[:text],
          prompt_lang: "zh-TW",
          answer: glyph[:value],
          distractors: others.map { |o| o[:value] },
          note: glyph[:pinyin]
        )
      }
    end

    def myriad_items(count)
      MYRIAD_ANCHORS.cycle.first(count).map { |value|
        build(
          id: "myriad:#{value}",
          prompt: grouped(value),
          answer: Numerals.spell(value),
          distractors: magnitude_neighbours(value).map { |n| Numerals.spell(n) },
          answer_lang: "zh-TW",
          note: value.to_s
        )
      }
    end

    def reading_items(count)
      count.times.map {
        value = rng.rand(100..99_999_999)
        build(
          id: "reading:#{value}",
          prompt: Numerals.spell(value),
          prompt_lang: "zh-TW",
          answer: grouped(value),
          distractors: magnitude_neighbours(value).map { |n| grouped(n) }
        )
      }
    end

    def trap_items(count)
      TRAPS.cycle.first(count).map { |value|
        build(
          id: "trap:#{value}",
          prompt: grouped(value),
          answer: Numerals.spell(value),
          distractors: trap_distractors(value),
          answer_lang: "zh-TW",
          note: value.to_s
        )
      }
    end

    def roc_items(count)
      count.times.map {
        roc = rng.rand(60..120)
        build(
          id: "roc:#{roc}",
          prompt: "民國#{Numerals.spell(roc)}年",
          prompt_lang: "zh-TW",
          answer: (roc + ROC_OFFSET).to_s,
          distractors: [roc + ROC_OFFSET + 1, roc + ROC_OFFSET - 1, roc + 1900].uniq.take(CHOICES - 1).map(&:to_s)
        )
      }
    end

    def trap_distractors(value)
      candidates = [
        Numerals.spell(value, liang: false),
        Numerals.spell(value).delete("零"),
        Numerals.spell(value * 10),
        Numerals.spell(value / 10)
      ]
      correct = Numerals.spell(value)
      candidates.uniq.reject { |c| c == correct || c.blank? }.first(CHOICES - 1)
    end

    def magnitude_neighbours(value)
      [value * 10, value / 10, value * 100]
        .filter_map { |n|
          next if n.zero? || n > Numerals::MAX

          n
        }
        .uniq
        .first(CHOICES - 1)
    end

    def grouped(value)
      value.to_s.reverse.scan(/\d{1,4}/).join(" ").reverse
    end

    def build(id:, prompt:, answer:, distractors:, prompt_lang: nil, answer_lang: nil, note: nil)
      {
        id:,
        prompt:,
        prompt_lang:,
        answer:,
        answer_lang:,
        note:,
        distractors: distractors.first(CHOICES - 1)
      }
    end
  end
end
