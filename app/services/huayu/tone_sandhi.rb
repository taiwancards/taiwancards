# frozen_string_literal: true

module Huayu
  class ToneSandhi
    YI = "一"
    BU = "不"
    ORDINAL = "第"
    COUNTING = %w[〇 零 一 二 三 四 五 六 七 八 九 十].to_set.freeze
    MONTH = "月"
    DATE_DAYS = %w[日 號].to_set.freeze
    NEUTRAL = 5
    UNDERLYING = {"個" => 4}.freeze

    def self.surface_tones(chars:, base_tones:, phrase_starts: [], word_ends: [])
      new(chars, base_tones, phrase_starts:, word_ends:).surface
    end

    def initialize(chars, base_tones, phrase_starts: [], word_ends: [])
      @chars = chars
      @base = base_tones.map(&:to_i)
      @phrase_starts = phrase_starts.to_set
      @word_ends = word_ends.to_set
    end

    def surface
      tones = @base.dup
      apply_yi_bu(tones)
      apply_third_tone(tones)
      tones
    end

    private

    def apply_yi_bu(tones)
      @chars.each_index do |i|
        following = following_tone(i)
        case @chars[i]
        when YI
          tones[i] = (following.nil? || plain_yi?(i)) ? 1 : shifted(i, following)
        when BU
          tones[i] = shifted(i, following)
        end
      end
    end

    def shifted(index, following)
      return 2 if following == 4
      return @base[index] if following == NEUTRAL && [2, 4].include?(@base[index])

      4
    end

    def following_tone(index)
      return nil if @phrase_starts.include?(index + 1)

      tone = @base[index + 1]
      (tone == NEUTRAL) ? UNDERLYING.fetch(@chars[index + 1], tone) : tone
    end

    def plain_yi?(index)
      before = (index.zero? || @phrase_starts.include?(index)) ? nil : @chars[index - 1]
      after = @chars[index + 1]
      counted = before == ORDINAL || COUNTING.include?(before) || COUNTING.include?(after)
      dated = after == MONTH || (before == MONTH && DATE_DAYS.include?(after))

      counted || dated || @word_ends.include?(index)
    end

    def apply_third_tone(tones)
      run = []
      flush = lambda do
        run[0...-1].each { |index| tones[index] = 2 } if run.size >= 2
        run = []
      end

      @base.each_index do |i|
        flush.call if @phrase_starts.include?(i)
        if @base[i] == 3 && !yi_bu?(i)
          run << i
        else
          flush.call
        end
      end

      flush.call
    end

    def yi_bu?(index)
      [YI, BU].include?(@chars[index])
    end
  end
end
