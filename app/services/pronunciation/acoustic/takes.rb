# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Takes
      GAP_MS = 200.0
      MIN_TAKE_MS = 140.0
      MAX = 3
      MAX_SYLLABLES = 4
      EVEN = (0.55..1.8)

      module_function

      def wanted(analysis, syllables, asked, least_ms: 0.0)
        return 1 if asked.to_i < 2 || syllables > MAX_SYLLABLES

        [windows(analysis, asked, least_ms:).length, 1].max
      end

      def windows(analysis, asked, least_ms: 0.0)
        runs = runs_of(analysis)
        return [] if runs.empty?

        wide = [asked.to_i, MAX, runs.length].min
        wide.downto(2) do |count|
          split = cut(runs, count, least_ms)
          return split if split
        end

        [[runs.first[0], runs.last[1]]]
      end

      def runs_of(analysis)
        energy = analysis[:energy]
        return [] if energy.nil? || energy.length < 6

        Features.speech_runs(analysis)
      end

      def cut(runs, count, least_ms)
        gaps = runs.each_cons(2).map { |(_, before), (after, _)| after - before }
        widest = gaps.sort.last(count - 1).min
        return nil if widest * Features::HOP_MS < GAP_MS

        groups = split_at(runs, gaps, widest)
        return nil unless groups.length == count

        spans = groups.map { |group| [group.first[0], group.last[1]] }
        return nil if spans.any? { |lo, hi| (hi - lo + 1) * Features::HOP_MS < least_ms }

        even?(groups) ? spans : nil
      end

      def split_at(runs, gaps, least)
        groups = [[runs.first]]
        gaps.each_with_index do |gap, index|
          gap >= least ? groups << [runs[index + 1]] : groups.last << runs[index + 1]
        end

        groups
      end

      def even?(groups)
        spoken = groups.map { |group| group.sum { |lo, hi| hi - lo + 1 } * Features::HOP_MS }
        return false if spoken.min < MIN_TAKE_MS

        middle = DTW::Statistics.median(spoken)
        middle.positive? && spoken.all? { |ms| EVEN.cover?(ms / middle) }
      end

      def spans_within(analysis, window, syllables)
        lo, hi = window
        return [window] if syllables <= 1

        inside = Features.speech_runs(analysis).select { |from, to| from >= lo && to <= hi }
        return inside if inside.length == syllables

        Features.forced_spans(analysis, syllables, bounds: window)
      end

      def group(spans, syllables, takes)
        return nil if spans.nil? || spans.length != syllables * takes

        Array.new(takes) { |take| spans[(take * syllables), syllables] }
      end
    end
  end
end
