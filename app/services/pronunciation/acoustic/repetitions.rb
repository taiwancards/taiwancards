# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Repetitions
      GAP_MS = 90.0
      MIN_RUN_MS = 110.0
      MARGIN_DB = 9.0
      PEAK_WINDOW_DB = 30.0

      module_function

      def split(an, expected:)
        runs = runs_of(an)
        return [] if runs.empty?
        return runs.first(expected) if runs.length <= expected

        merge_down(runs, expected)
      end

      def runs_of(an)
        energy = an[:energy]
        return [] if energy.length < 6

        threshold = threshold_for(energy)
        gap = (GAP_MS / Features::HOP_MS).round
        minimum = (MIN_RUN_MS / Features::HOP_MS).round

        collect(energy, threshold, gap).select { |lo, hi| hi - lo >= minimum }
      end

      def threshold_for(energy)
        audible = energy.reject { |v| v <= Features::SILENCE_DB }
        sorted = (audible.length >= 3 ? audible : energy).sort
        floor = sorted[(sorted.length * 0.10).floor]
        peak = sorted[(sorted.length * 0.95).floor]
        [floor + MARGIN_DB, peak - PEAK_WINDOW_DB].max
      end

      def collect(energy, threshold, gap)
        runs = []
        start = nil
        quiet = 0

        energy.each_with_index do |value, i|
          if value > threshold
            start ||= i - quiet
            quiet = 0
            next
          end

          next if start.nil?

          quiet += 1
          next if quiet < gap

          runs << [start, i - quiet]
          start = nil
          quiet = 0
        end

        runs << [start, energy.length - 1] if start
        runs
      end

      def merge_down(runs, expected)
        list = runs.dup

        while list.length > expected
          index = (0...(list.length - 1)).min_by { |i| list[i + 1][0] - list[i][1] }
          list[index] = [list[index][0], list[index + 1][1]]
          list.delete_at(index + 1)
        end

        list
      end
    end
  end
end
