# frozen_string_literal: true

module Pronunciation
  module Acoustic
    class Cepstra
      attr_reader :length

      def initialize(spectra:, mfcc:, size:)
        @spectra = spectra
        @mfcc = mfcc
        @size = size
        @length = spectra.length
        @raw = {}
        @rows = {}
        @mean = nil
      end

      def normalize(range)
        total = Array.new(@size, 0.0)
        count = 0

        range.each do |index|
          row = raw(index)
          next unless row

          d = 0
          while d < @size
            total[d] += row[d]
            d += 1
          end

          count += 1
        end

        return self unless count.positive?

        total.map! { |value| value / count }
        @mean = total
        self
      end

      def [](index)
        return nil if index.nil? || index.negative? || index >= @length

        @rows[index] ||= centered(index)
      end

      def computed = @raw.size

      private

      def centered(index)
        row = raw(index)
        return row if @mean.nil?

        Array.new(@size) { |d| row[d] - @mean[d] }
      end

      def raw(index)
        return nil if index.nil? || index.negative? || index >= @length

        @raw[index] ||= @mfcc.call(@spectra[index])
      end
    end
  end
end
