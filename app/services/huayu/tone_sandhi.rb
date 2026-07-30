# frozen_string_literal: true

module Huayu
  class ToneSandhi
    YI = "一"
    BU = "不"

    def self.surface_tones(chars:, base_tones:)
      new(chars, base_tones).surface
    end

    def initialize(chars, base_tones)
      @chars = chars
      @base = base_tones.map(&:to_i)
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
        following = @base[i + 1]
        case @chars[i]
        when YI
          tones[i] = following.nil? ? 1 : ((following == 4) ? 2 : 4)
        when BU
          tones[i] = (following == 4) ? 2 : 4
        end
      end
    end

    def apply_third_tone(tones)
      run = []
      flush = lambda do
        run[0...-1].each { |index| tones[index] = 2 } if run.size >= 2
        run = []
      end

      @base.each_index do |i|
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
