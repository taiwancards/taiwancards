# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Takes
      GAP_MS = 260.0
      MIN_TAKE_MS = 140.0
      MAX = 3
      MAX_SYLLABLES = 4

      module_function

      def wanted(analysis, syllables, asked)
        return 1 if asked.to_i < 2 || syllables > MAX_SYLLABLES

        found = runs_of(analysis).length
        return 1 if found < 2

        [asked.to_i, found, MAX].min
      end

      def runs_of(analysis)
        energy = analysis[:energy]
        return [] if energy.nil? || energy.length < 6

        least = (MIN_TAKE_MS / Features::HOP_MS).round
        joined(Features.speech_runs(analysis)).select { |lo, hi| hi - lo >= least }
      end

      def joined(runs)
        gap = (GAP_MS / Features::HOP_MS).round
        runs.each_with_object([]) do |(lo, hi), out|
          last = out.last
          if last && lo - last[1] < gap
            last[1] = hi
          else
            out << [lo, hi]
          end
        end
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
