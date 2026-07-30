# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Onset
      HOP_MS = 1.0
      WIN_MS = 5.0
      PAD_MS = 60.0
      VOICE_HZ = 800.0
      NOISE_HZ = 1200.0
      VOICE_DROP_DB = 10.0
      VOICE_BACKOFF_DB = 22.0
      VOICE_SUSTAIN_DB = 15.0
      VOICE_OVER_NOISE_DB = 2.0
      SUSTAIN_MS = 15.0
      MIN_BURST_RANGE_DB = 8.0
      MIN_BURST_RISE_DB = 6.0
      BURST_LEVEL_SHARE = 0.5
      BURST_HOLD_SHARE = 0.25
      MAX_GAP_MS = 25.0
      MIN_VOT_MS = 3.0
      MAX_VOT_MS = 250.0
      EDGE_MS = 4.0
      MIN_REGION_MS = 40.0

      module_function

      def measure(samples, rate, from_sample, to_sample, back_ms: 0.0, from_edge: false)
        grid = envelopes(samples, rate, from_sample, to_sample, back_ms: back_ms)
        return nil if grid.nil?

        first = [grid[:origin] - ms_to_steps(back_ms), 0].max
        last = [grid[:voice].length - 1, grid[:last]].min
        return nil if last - first < 8

        voice_at = voicing_onset(grid, first, last)
        return nil if voice_at.nil?

        burst_at = noise_onset(grid[:noise], first, voice_at)
        burst_at ||= first if from_edge

        {
          voice_ms: at_ms(grid, voice_at),
          burst_ms: burst_at && at_ms(grid, burst_at),
          truncated: burst_at ? (grid[:from_start] && burst_at - first < ms_to_steps(EDGE_MS)) : false
        }.tap { |out| out[:vot_ms] = out[:burst_ms] && (out[:voice_ms] - out[:burst_ms]) }
      end

      def envelopes(samples, rate, from_sample, to_sample, back_ms: 0.0)
        pad = (rate * PAD_MS / 1000.0).round
        lo = [from_sample - [pad, (rate * back_ms / 1000.0).round].max, 0].max
        hi = [to_sample + pad, samples.length].min
        return nil if (hi - lo) < (rate * MIN_REGION_MS / 1000.0)

        segment = samples[lo...hi]
        hop = [(rate * HOP_MS / 1000.0).round, 1].max
        win = [(rate * WIN_MS / 1000.0).round, 2].max

        voice = Dsp.envelope_db(Dsp.lowpass(segment, rate, VOICE_HZ), win, hop)
        noise = Dsp.envelope_db(Dsp.highpass(segment, rate, NOISE_HZ), win, hop)
        return nil if voice.length < 12 || noise.length < 12

        {
          voice: voice,
          noise: noise,
          hop: hop,
          win: win,
          rate: rate,
          base: lo,
          from: from_sample,
          from_start: lo.zero?,
          origin: [((from_sample - lo).to_f / hop).round, 0].max,
          last: [((to_sample - lo).to_f / hop).round, voice.length - 1].min
        }
      end

      def at_ms(grid, index)
        center = grid[:base] + (index * grid[:hop]) + (grid[:win] / 2.0)
        (center - grid[:from]) * 1000.0 / grid[:rate]
      end

      def ms_to_steps(ms) = (ms / HOP_MS).round

      def voicing_onset(grid, first, last)
        voice = grid[:voice]
        noise = grid[:noise]
        window = voice[first..last]
        peak = window.max
        base = window.min
        return nil if peak - base < 6.0

        threshold = [peak - VOICE_DROP_DB, base + 6.0].max
        sustain = ms_to_steps(SUSTAIN_MS)
        floor = peak - VOICE_SUSTAIN_DB

        start = (first..last).find do |i|
          next false if voice[i] < threshold
          next false if noise[i] - voice[i] > VOICE_OVER_NOISE_DB

          tail = voice[i..[i + sustain, last].min]
          Dsp.median(tail) >= floor
        end

        return nil if start.nil?

        retreat = [peak - VOICE_BACKOFF_DB, base + 3.0].max
        start -= 1 while start > first &&
          voice[start - 1] >= retreat &&
          noise[start - 1] -
          voice[start - 1] <= VOICE_OVER_NOISE_DB
        start
      end

      def noise_onset(noise, first, voice_at)
        latest = voice_at - ms_to_steps(MIN_VOT_MS)
        window = noise[first...latest]
        return nil if window.nil? || window.length < 4

        sorted = window.sort
        floor = sorted[(sorted.length * 0.10).floor]
        span = sorted.last - floor
        return nil if span < MIN_BURST_RANGE_DB

        enter = floor + [MIN_BURST_RISE_DB, span * BURST_LEVEL_SHARE].max
        hold = floor + (span * BURST_HOLD_SHARE)
        gap = ms_to_steps(MAX_GAP_MS)

        (first...latest).find { |i| noise[i] >= enter && unbroken?(noise, i, voice_at, hold, gap) }
      end

      def unbroken?(noise, from, voice_at, hold, gap)
        run = 0
        (from...voice_at).each do |i|
          if noise[i] < hold
            run += 1
            return false if run > gap
          else
            run = 0
          end
        end

        true
      end

      def plausible?(vot_ms, from_edge: false)
        return false if vot_ms.nil? || vot_ms > MAX_VOT_MS

        from_edge ? vot_ms >= 0.0 : vot_ms >= MIN_VOT_MS
      end
    end
  end
end
