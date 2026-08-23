# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Timbre
      MIN_SYLLABLES = 3

      module_function

      def align(pairs)
        usable = pairs.select { |spoken, wanted| comparable?(spoken, wanted) }
        return if usable.length < MIN_SYLLABLES

        shift = difference(mean_of(usable.map(&:last)), mean_of(usable.map(&:first)))
        usable.each { |spoken, _| shift!(spoken, shift) }
      end

      def comparable?(spoken, wanted)
        return false if spoken.blank? || wanted.blank?

        spoken.length == wanted.length && spoken.first.length == wanted.first.length
      end

      def mean_of(frames)
        rows = frames.first.length
        columns = frames.first.first.length
        Array.new(rows) do |row|
          Array.new(columns) { |column| frames.sum { |frame| frame[row][column] } / frames.length }
        end
      end

      def difference(wanted, spoken)
        wanted.each_index.map { |row| wanted[row].each_index.map { |i| wanted[row][i] - spoken[row][i] } }
      end

      def shift!(frames, shift)
        frames.each_index do |row|
          frames[row].each_index { |i| frames[row][i] += shift[row][i] }
        end
      end
    end
  end
end
