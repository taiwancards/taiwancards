# frozen_string_literal: true

module Pronunciation
  module Acoustic
    class Spectra
      PREEMPHASIS = 0.97

      attr_reader :length

      def initialize(samples:, win:, hop:, window:, spectrum:, length:)
        @samples = samples
        @win = win
        @hop = hop
        @window = window
        @spectrum = spectrum
        @length = length
        @cache = {}
      end

      def [](index)
        return nil if index.nil? || index.negative? || index >= @length

        @cache[index] ||= power_of(index)
      end

      def computed = @cache.size

      private

      def power_of(index)
        pre = DSP::Framing.preemphasis(@samples[index * @hop, @win], coefficient: PREEMPHASIS)
        @spectrum.power(Array.new(@win) { |i| pre[i] * @window[i] })
      end
    end
  end
end
