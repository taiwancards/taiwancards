# frozen_string_literal: true

module Pronunciation
  module Acoustic
    class Alignment
      MIN_SYLLABLE_MS = 60.0
      MAX_SYLLABLE_MS = 1400.0
      SPAN_FACTOR = 2.6
      TEMPO_RANGE = (0.45..2.2)
      DURATION_SIGMA = 0.42
      DURATION_CAP = 9.0
      CHANGE_WEIGHT = 1.0
      ENERGY_WEIGHT = 0.9
      VOICING_WEIGHT = 0.7
      BOUNDARY_WEIGHT = 1.6
      DEFAULT_MS = 220.0

      Cues = Data.define(:score, :length)

      def initialize(hop_ms: Features::HOP_MS)
        @hop_ms = hop_ms
      end

      def spans(analysis, templates)
        count = templates.length
        return nil if count.zero?

        low, high = Features.utterance_bounds(analysis, count)
        return nil if low.nil? || high.nil?

        frames = high - low + 1
        return nil if frames < count * minimum_frames

        return [[low, high]] if count == 1

        cues = cues_for(analysis, low, high)
        wanted = expected_frames(templates, frames)
        boundaries = search(cues, wanted, frames)
        return nil if boundaries.nil?

        (0...count).map { |i| [low + boundaries[i], low + boundaries[i + 1] - 1] }
      end

      private

      def minimum_frames = [(MIN_SYLLABLE_MS / @hop_ms).round, 2].max

      def maximum_frames = (MAX_SYLLABLE_MS / @hop_ms).round

      def cues_for(analysis, low, high)
        length = high - low + 1
        change = Array.new(length, 0.0)
        index = 1
        while index < length
          change[index] = distance(analysis[:mfcc][low + index - 1], analysis[:mfcc][low + index])
          index += 1
        end

        change[0] = change[1] || 0.0

        energy = (low..high).map { |i| analysis[:energy][i].to_f }
        onset = voicing_onsets(analysis, low, high)

        score = Array.new(length)
        change_z = standardize(change)
        energy_z = standardize(energy)
        index = 0
        while index < length
          score[index] = (CHANGE_WEIGHT * change_z[index]) -
            (ENERGY_WEIGHT * energy_z[index]) +
            (VOICING_WEIGHT * onset[index])
          index += 1
        end

        Cues.new(score: score, length: length)
      end

      def voicing_onsets(analysis, low, high)
        f0 = analysis[:f0]
        Array.new(high - low + 1) do |index|
          here = f0[low + index].to_f.positive?
          before = f0[low + index - 1].to_f.positive?
          here && !before ? 1.0 : 0.0
        end
      end

      def distance(previous, current)
        return 0.0 if previous.nil? || current.nil?

        total = 0.0
        index = 1
        while index < current.length
          delta = current[index] - previous[index]
          total += delta * delta
          index += 1
        end

        Math.sqrt(total)
      end

      def standardize(values)
        mean = values.sum / values.length
        variance = values.sum { |value| (value - mean) ** 2 } / values.length
        spread = Math.sqrt(variance)
        return Array.new(values.length, 0.0) unless spread.positive?

        values.map { |value| (value - mean) / spread }
      end

      def expected_frames(templates, frames)
        wanted = templates.map do |template|
          ms = template&.dig("voiced_ms", "median").to_f
          ms = template&.dig("duration_ms", "median").to_f unless ms.positive?
          ms.positive? ? ms : DEFAULT_MS
        end

        total = wanted.sum
        tempo = (frames * @hop_ms / total).clamp(TEMPO_RANGE.min, TEMPO_RANGE.max)
        wanted.map { |ms| (ms * tempo / @hop_ms).clamp(minimum_frames, maximum_frames) }
      end

      # Each unit may stretch or shrink by SPAN_FACTOR around what its template
      # expects, which bounds the search without fixing an absolute duration.
      def bounds_for(wanted, length)
        total = wanted.sum
        wanted.map do |target|
          share = target / total * length
          reach = [target, share].max
          [
            [(reach / SPAN_FACTOR).floor, minimum_frames].max,
            [(reach * SPAN_FACTOR).ceil, maximum_frames].min
          ]
        end
      end

      def search(cues, wanted, length_hint)
        count = wanted.length
        length = cues.length
        limits = bounds_for(wanted, length_hint)
        ranges = position_ranges(limits, length)
        if ranges.nil?
          limits = Array.new(count) { [minimum_frames, maximum_frames] }
          ranges = position_ranges(limits, length)
        end

        return nil if ranges.nil?

        boundary = Array.new(length) { |i| i.zero? ? 0.0 : -BOUNDARY_WEIGHT * cues.score[i] }
        best = Array.new(count + 1) { Array.new(length + 1, Float::INFINITY) }
        from = Array.new(count + 1) { Array.new(length + 1) }
        best[0][0] = 0.0

        unit = 1
        while unit <= count
          low_bound, high_bound = limits[unit - 1]
          table = duration_table(wanted[unit - 1], low_bound, high_bound)
          row = best[unit]
          previous = best[unit - 1]
          trace = from[unit]
          from_low, from_high = ranges[unit - 1]
          to_low, to_high = ranges[unit]

          position = to_low
          while position <= to_high
            first = [position - high_bound, from_low].max
            last = [position - low_bound, from_high].min
            start = first
            while start <= last
              carried = previous[start]
              unless carried.infinite?
                total = carried + boundary[start] + table[position - start - low_bound]
                if total < row[position]
                  row[position] = total
                  trace[position] = start
                end
              end

              start += 1
            end

            position += 1
          end

          unit += 1
        end

        return nil if best[count][length].infinite?

        backtrack(from, count, length)
      end

      def backtrack(from, count, length)
        boundaries = Array.new(count + 1)
        boundaries[count] = length
        position = length
        unit = count
        while unit.positive?
          start = from[unit][position]
          return nil if start.nil?

          boundaries[unit - 1] = start
          position = start
          unit -= 1
        end

        boundaries
      end

      # A unit can only end where enough frames remain for the units after it,
      # which keeps the search off most of the grid.
      def position_ranges(limits, length)
        count = limits.length
        forward = [[0, 0]]
        limits.each { |low, high| forward << [forward.last[0] + low, forward.last[1] + high] }
        backward = Array.new(count + 1) { [0, 0] }
        (count - 1).downto(0) do |unit|
          backward[unit] = [backward[unit + 1][0] + limits[unit][0], backward[unit + 1][1] + limits[unit][1]]
        end

        ranges = (0..count).map do |unit|
          low = [forward[unit][0], length - backward[unit][1]].max
          high = [forward[unit][1], length - backward[unit][0]].min
          return nil if low > high

          [low, high]
        end

        ranges
      end

      def duration_table(target, low_bound, high_bound)
        Array.new(high_bound - low_bound + 1) { |offset| duration_cost(low_bound + offset, target) }
      end

      def duration_cost(actual, target)
        ratio = Math.log(actual.to_f / target)
        [(ratio / DURATION_SIGMA) ** 2, DURATION_CAP].min
      end
    end
  end
end
