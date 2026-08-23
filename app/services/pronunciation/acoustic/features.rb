# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Features
      FRAME_MS = 25.0
      HOP_MS = 10.0
      NFFT = 1024
      N_MEL = 26
      N_MFCC = 13

      TONE_POINTS = 16
      FORMANT_POINTS = 8
      FORMANT_MERGED = 0.95
      FORMANT_F1_MERGED = 0.8
      ONSET_POINT = 1
      VOWEL_WINDOW = (2..3)
      TAIL_SHARE = 0.75
      BODY_SHARE = (0.35..0.6)
      MFCC_POINTS = 12

      module_function

      CANONICAL_F3 = 3000.0

      def analyze(samples, sr, speaker_f3: nil, f0_floor: nil)
        win = (sr * FRAME_MS / 1000.0).round
        hop = (sr * HOP_MS / 1000.0).round
        window = DSP::Window.hamming(win)
        spectrum = DSP::Spectrum.new(NFFT)

        energy = []
        zcr = []
        centers = []

        pos = 0
        while pos + win <= samples.length
          raw = samples[pos, win]
          energy << DSP::Energy.frame_db(raw)
          zcr << DSP::Energy.zero_crossing_rate(raw)
          centers << ((pos + (win / 2.0)) / sr)
          pos += hop
        end

        f3_est = speaker_f3 || estimate_f3(samples, sr, win, hop, energy)
        warp = f3_est ? (f3_est / CANONICAL_F3).clamp(0.75, 1.35) : 1.0
        max_formant = 5500.0 * warp

        bank = DSP::MelFilterbank.new(sample_rate: sr, size: NFFT, filters: N_MEL, low: 50.0, warp: warp)
        mfcc = DSP::Mfcc.new(filterbank: bank, coefficients: N_MFCC, spectrum: spectrum)

        powers = Spectra.new(
          samples: samples,
          win: win,
          hop: hop,
          window: window,
          spectrum: spectrum,
          length: centers.length
        )

        mfccs = Cepstra.new(spectra: powers, mfcc: mfcc, size: N_MFCC)
        speech_lo, speech_hi = energy_bounds(energy)
        mfccs.normalize(speech_lo..speech_hi) if speech_hi > speech_lo

        pitch, yin_offset = pitch_track(samples, sr, energy, hop, f0_floor)
        yin_centers = pitch.times.map { |t| t + yin_offset }

        f0 = align(pitch.f0, yin_centers, centers)
        conf = align(pitch.confidence, yin_centers, centers)

        {
          sr: sr,
          win: win,
          hop: hop,
          nfft: NFFT,
          centers: centers,
          energy: energy,
          zcr: zcr,
          powers: powers,
          mfcc: mfccs,
          f0: f0,
          conf: conf,
          n: centers.length,
          samples: samples,
          f3_est: f3_est,
          warp: warp,
          max_formant: max_formant
        }
      end

      def waveform_of(samples, sr) = DSP::Waveform.new(samples: samples, sample_rate: sr)

      PITCH_MARGIN_MS = 500.0

      PITCH_FLOOR = (50.0..DSP::Yin::DEFAULT_MINIMUM_HZ)
      FLOOR_SHARE = 0.75

      def floor_for(f0_low)
        return nil unless f0_low.to_f.positive?

        (f0_low * FLOOR_SHARE).clamp(PITCH_FLOOR.min, PITCH_FLOOR.max)
      end

      def pitch_track(samples, sr, energy, hop, f0_floor = nil)
        yin = DSP::Yin.new(
          hop_seconds: HOP_MS / 1000.0,
          minimum_frequency: f0_floor || DSP::Yin::DEFAULT_MINIMUM_HZ
        )
        span = audible_span(energy, hop, samples.length)
        return [yin.call(waveform_of(samples, sr)), 0.0] if span.nil?

        from, to = span
        [yin.call(waveform_of(samples[from...to], sr)), from / sr.to_f]
      end

      def audible_span(energy, hop, length)
        return nil if energy.length < 3

        floor, peak = background_of(energy)
        threshold = [floor + NOISE_MARGIN_DB, peak - PEAK_WINDOW_DB].max
        first = energy.index { |value| value > threshold }
        last = energy.rindex { |value| value > threshold }
        return nil if first.nil? || last.nil?

        margin = (PITCH_MARGIN_MS / HOP_MS).round
        from = [(first - margin) * hop, 0].max
        to = [(last + margin) * hop, length].min
        to - from < length ? [from, to] : nil
      end

      def formant_extractor(sr, ceiling)
        factor = [(sr / (2.0 * ceiling)).round, 1].max
        DSP::Formants.new(maximum_frequency: sr / (2.0 * factor))
      end

      F3_PROBES = 40
      F3_MIN_HZ = 1800.0
      F3_MAX_HZ = 4200.0
      F3_MIN_PROBES = 5

      def estimate_f3(samples, sr, win, hop, energy)
        return nil if energy.empty?

        sorted = energy.compact.sort
        thr = sorted[(sorted.length * 0.6).to_i]
        loud = energy.each_index.select { |i| energy[i] && energy[i] >= thr && (i * hop) + win <= samples.length }
        return nil if loud.length < F3_MIN_PROBES

        extractor = formant_extractor(sr, DSP::Formants::DEFAULT_MAXIMUM_HZ)
        vals = probes(loud).filter_map do |i|
          f = extractor.call(waveform_of(samples[i * hop, win], sr))[2]
          f if f && f > F3_MIN_HZ && f < F3_MAX_HZ
        end

        return nil if vals.length < F3_MIN_PROBES

        vals.sort[vals.length / 2]
      end

      def probes(indexes)
        return indexes if indexes.length <= F3_PROBES

        Array.new(F3_PROBES) { |k| indexes[(k * indexes.length) / F3_PROBES] }
      end

      def align(values, src_times, dst_times)
        return Array.new(dst_times.length, 0.0) if values.empty?

        dst_times.map do |t|
          idx = ((t - src_times[0]) / (src_times.length > 1 ? src_times[1] - src_times[0] : 1.0)).round
          idx = idx.clamp(0, values.length - 1)
          values[idx]
        end
      end

      def energy_bounds(e)
        return [0, e.length - 1] if e.length < 3

        sorted = e.sort
        floor = sorted[(sorted.length * 0.10).floor]
        peak = sorted[(sorted.length * 0.95).floor]
        thr = [floor + (0.30 * (peak - floor)), peak - 35.0].max
        first = e.index { |v| v > thr } || 0
        last = e.rindex { |v| v > thr } || (e.length - 1)
        [first, last]
      end

      SILENCE_DB = -119.0
      NOISE_MARGIN_DB = 8.0
      PEAK_WINDOW_DB = 35.0
      MIN_HEADROOM_DB = 6.0

      def speech_bounds(an)
        e = an[:energy]
        return [0, an[:n] - 1] if e.length < 3

        floor, peak = background_level(an)
        thr = threshold(peak, floor)
        first, last = loudest_run(e, thr)
        return [0, an[:n] - 1] if first.nil? || last.nil?

        first = past_transient(e, first, last, thr)

        [back_off_to_burst(e, first, floor), last]
      end

      BURST_REACH_MS = 150.0
      BURST_RISE_DB = 6.0
      BURST_FLOOR_DB = 4.0

      def back_off_to_burst(e, first, floor)
        reach = [(BURST_REACH_MS / HOP_MS).round, first].min
        burst = first
        (1..reach).each do |k|
          i = first - k
          break if i < 1

          burst = i if e[i] - e[i - 1] > BURST_RISE_DB && e[i] > floor + BURST_FLOOR_DB
        end

        burst
      end

      UTTERANCE_KEEP_DB = 26.0

      def utterance_bounds(an, syllables)
        return speech_bounds(an) if syllables.to_i <= 1

        runs = speech_runs(an)
        return speech_bounds(an) if runs.length < 2

        e = an[:energy]
        loudest = runs.map { |from, to| (from..to).max_by { |i| e[i].to_f } }.map { |i| e[i].to_f }.max
        kept = runs.select { |from, to| (from..to).any? { |i| e[i].to_f >= loudest - UTTERANCE_KEEP_DB } }
        return speech_bounds(an) if kept.empty?

        floor, = background_level(an)
        [back_off_to_burst(e, kept.first[0], floor), kept.last[1]]
      end

      def threshold(peak, floor)
        thr = [floor + NOISE_MARGIN_DB, peak - PEAK_WINDOW_DB].max
        [thr, peak - MIN_HEADROOM_DB].min
      end

      BACKGROUND_BIN_DB = 3.0
      BACKGROUND_GAP_DB = 15.0

      def background_level(an) = background_of(an[:energy])

      def background_of(e)
        audible = e.reject { |v| v <= SILENCE_DB }
        sorted = (audible.length >= 3 ? audible : e).sort
        peak = sorted[(sorted.length * 0.95).floor]
        quiet = background_db(sorted) || sorted[(sorted.length * 0.10).floor]

        [[quiet, leading_background(e, peak)].compact.max, peak]
      end

      def background_db(sorted)
        return nil if sorted.length < 3

        densest = sorted.group_by { |v| (v / BACKGROUND_BIN_DB).floor }.max_by { |_, group| group.length }.last
        level = densest[densest.length / 2]
        level <= sorted.last - BACKGROUND_GAP_DB ? level : nil
      end

      LEAD_MAX_FRAMES = 25
      LEAD_MIN_FRAMES = 5
      LEAD_SPREAD_DB = 12.0

      def leading_background(e, peak)
        head = []
        e.first([LEAD_MAX_FRAMES, e.length / 4].min).each do |v|
          break if head.any? && (v - head.first).abs > LEAD_SPREAD_DB

          head << v
        end

        return nil if head.length < LEAD_MIN_FRAMES

        level = DTW::Statistics.median(head)
        level <= peak - BACKGROUND_GAP_DB ? level : nil
      end

      RUN_GAP_MS = 150.0

      def loudest_run(e, thr)
        crest = e.each_with_index.max_by(&:first)&.last
        return [nil, nil] if crest.nil? || e[crest] <= thr

        [walk(e, crest, thr, -1), walk(e, crest, thr, 1)]
      end

      def walk(e, from, thr, step)
        allowed = (RUN_GAP_MS / HOP_MS).round
        edge = from
        quiet = 0
        i = from

        while (i += step) >= 0 && i < e.length
          if e[i] > thr
            quiet = 0
            edge = i
          else
            quiet += 1
            break if quiet > allowed
          end
        end

        edge
      end

      TRANSIENT_MS = 70.0
      TRANSIENT_GAP_MS = 30.0

      def past_transient(e, first, last, thr)
        blip = (TRANSIENT_MS / HOP_MS).round
        gap = (TRANSIENT_GAP_MS / HOP_MS).round
        cursor = first

        while cursor < last
          loud = cursor
          loud += 1 while loud <= last && e[loud] > thr
          break if loud - cursor > blip

          quiet = loud
          quiet += 1 while quiet <= last && e[quiet] <= thr
          break if quiet - loud < gap

          following = (quiet..last).find { |i| e[i] > thr }
          break if following.nil?

          cursor = following
        end

        cursor
      end

      VALLEY_PLATEAU_DB = 2.0
      KEEP_RUN_DB = 25.0
      MIN_RUN_MS = 60.0

      def speech_runs(an)
        e = an[:energy]
        return [] if e.length < 3

        floor, peak = background_level(an)
        thr = threshold(peak, floor)
        allowed = (RUN_GAP_MS / HOP_MS).round

        runs = []
        i = 0
        while i < e.length
          if e[i] > thr
            start = i
            last_loud = i
            quiet = 0
            j = i + 1
            while j < e.length && quiet <= allowed
              if e[j] > thr
                quiet = 0
                last_loud = j
              else
                quiet += 1
              end

              j += 1
            end

            runs << [start, last_loud]
            i = j
          else
            i += 1
          end
        end

        min_len = (MIN_RUN_MS / HOP_MS).round
        tall = runs.select { |a, b| b - a >= min_len && e[a..b].max > peak - KEEP_RUN_DB }
        tall.empty? ? runs.first(1) : tall
      end

      def syllable_spans(an, n_syllables)
        if n_syllables == 1
          lo, hi = speech_bounds(an)
          return nil if hi - lo < 4

          return [[lo, hi]]
        end

        runs = speech_runs(an)
        return nil if runs.empty?
        return runs if runs.length == n_syllables

        lo = runs.first[0]
        hi = runs.last[1]
        return nil if hi - lo < 4

        son = smooth(an[:energy][lo..hi])
        min_dist = [(110.0 / HOP_MS).round, 2].max

        peaks = find_peaks(son, n_syllables, min_dist)
        return nil unless peaks && peaks.length == n_syllables

        bounds = [0]
        (0...(peaks.length - 1)).each do |i|
          a = peaks[i]
          b = peaks[i + 1]
          valley = (a..b).min_by { |k| son[k] }
          limit = son[valley] + VALLEY_PLATEAU_DB
          valley += 1 while valley + 1 < b && son[valley + 1] <= limit
          bounds << valley
        end

        bounds << son.length - 1

        (0...n_syllables).map { |i| [lo + bounds[i], lo + bounds[i + 1]] }
      end

      def forced_spans(an, n_syllables, bounds: nil)
        lo, hi = bounds || speech_bounds(an)
        length = hi - lo + 1
        return nil if length < n_syllables * 3

        son = smooth(an[:energy][lo..hi])
        reach = [(length / (n_syllables * 2.0)).floor, 3].max
        cuts = [0]
        (1...n_syllables).each do |k|
          target = (length * k / n_syllables.to_f).round
          a = [target - reach, cuts.last + 2].max
          b = [target + reach, length - 2].min
          cuts << (a > b ? target.clamp(1, length - 2) : (a..b).min_by { |i| son[i] })
        end

        cuts << length - 1

        (0...n_syllables).map { |i| [lo + cuts[i], lo + cuts[i + 1]] }
      end

      def smooth(v)
        med = Array.new(v.length) do |i|
          a = v[[i - 1, 0].max]
          b = v[i]
          c = v[[i + 1, v.length - 1].min]
          [a, b, c].sort[1]
        end

        Array.new(med.length) do |i|
          lo = [i - 2, 0].max
          hi = [i + 2, med.length - 1].min
          med[lo..hi].sum / (hi - lo + 1).to_f
        end
      end

      def find_peaks(v, n, min_dist)
        cands = []
        (1...(v.length - 1)).each do |i|
          cands << i if v[i] >= v[i - 1] && v[i] >= v[i + 1]
        end

        cands = [v.each_with_index.max_by { |x, _| x }[1]] if cands.empty?
        cands.sort_by! { |i| -v[i] }

        chosen = []
        cands.each do |i|
          next if chosen.any? { |c| (c - i).abs < min_dist }

          chosen << i
          break if chosen.length == n
        end

        return nil if chosen.length < n

        chosen.sort
      end

      QUIET_START_DB = 12.0
      BACK_SEARCH_MS = 300.0
      LEAD_IN_MS = 40.0

      def lead_in?(an, span)
        e = an[:energy]
        needed = (LEAD_IN_MS / HOP_MS).round
        start = span[0]
        return false if start < needed

        limit = background_level(an).first + QUIET_START_DB
        e[(start - needed)...start].all? { |v| v < limit }
      end

      def unvoiced_lead_ms(an, span)
        conf = an[:conf]
        floor = background_level(an).first
        limit = (BACK_SEARCH_MS / HOP_MS).round
        run = 0
        i = span[0] - 1
        while i >= 0 && run < limit
          break if conf[i] >= 0.5 && an[:energy][i] > floor + QUIET_START_DB

          run += 1
          i -= 1
        end

        run * HOP_MS
      end

      def fine_onset(an, span, initial, utterance_initial)
        return nil unless Phonology.obstruent?(initial)

        quiet = lead_in?(an, span)
        edge = !quiet && utterance_initial
        hop = an[:hop]
        fine = Onset.measure(
          an[:samples],
          an[:sr],
          span[0] * hop,
          (span[1] + 1) * hop,
          back_ms: quiet ? unvoiced_lead_ms(an, span) : 0.0,
          from_edge: edge
        )
        return nil unless fine && Onset.plausible?(fine[:vot_ms], from_edge: edge)

        fine.merge(clean: !edge)
      end

      MAX_ONSET_MS = 300.0
      MAX_TAIL_MS = 250.0

      def syllable_parts(an, span, initial: nil, utterance_initial: true)
        lo, hi = span
        conf = an[:conf]
        voice_start = nil
        (lo..hi - 1).each do |i|
          if conf[i] > 0.55 && conf[i + 1] > 0.55
            voice_start = i
            break
          end
        end

        voice_start ||= lo

        voice_end = nil
        (lo..hi).reverse_each do |i|
          if conf[i] > 0.5
            voice_end = i
            break
          end
        end

        voice_end ||= hi

        lo = [lo, voice_start - (MAX_ONSET_MS / HOP_MS).round].max
        hi = [hi, voice_end + (MAX_TAIL_MS / HOP_MS).round].min
        span = [lo, hi]

        fine = fine_onset(an, span, initial, utterance_initial)
        burst = fine ? burst_frame(lo, fine[:burst_ms], voice_start) : lo

        {
          onset: lo,
          burst: burst,
          voice_start: voice_start,
          voice_end: [voice_end, voice_start].max,
          offset: hi,
          vot_ms: fine && fine[:vot_ms],
          vot_valid: !fine.nil?,
          vot_clean: fine ? fine[:clean] : false
        }
      end

      def burst_frame(lo, burst_ms, voice_start)
        (lo + (burst_ms / HOP_MS).round).clamp(0, voice_start)
      end

      def extract(an, span, initial: nil, utterance_initial: true, f0_reference: nil)
        parts = syllable_parts(an, span, initial: initial, utterance_initial: utterance_initial)
        lo = parts[:onset]
        hi = parts[:offset]
        vs = parts[:voice_start]
        ve = parts[:voice_end]
        sr = an[:sr]

        raw = octave_aligned(((vs..ve).map { |i| an[:f0][i] }), f0_reference)
        cleaned = clean_f0_track(raw)
        filled = fill_gaps(cleaned, 6)
        voiced_seq = filled.select { |v| v > 0.0 }
        ref = voiced_seq.empty? ? 0.0 : DTW::Statistics.median(voiced_seq)

        f0_curve = if ref > 0 && voiced_seq.length >= 4
          DSP::Curve.resample(voiced_seq.map { |f| DSP::Scales.hz_to_semitones(f, reference: ref) }, TONE_POINTS)
        else
          Array.new(TONE_POINTS, 0.0)
        end

        voiced_frames = voiced_seq.length
        total_frames = [ve - vs + 1, 1].max

        mfcc_traj = (vs..ve).map { |i| an[:mfcc][i] }
        mfcc_traj = [an[:mfcc][vs] || Array.new(N_MFCC, 0.0)] if mfcc_traj.empty?
        mfcc_rs = resample_matrix(mfcc_traj, MFCC_POINTS)

        win = an[:win]
        hop = an[:hop]
        f1 = []
        f2 = []
        f3 = []
        extractor = formant_extractor(sr, an[:max_formant] || DSP::Formants::DEFAULT_MAXIMUM_HZ)
        (vs..ve).each do |i|
          start = i * hop
          break if start + win > an[:samples].length

          fs = extractor.call(waveform_of(an[:samples][start, win], sr))
          f1 << (fs[0] || 0.0)
          f2 << (fs[1] || 0.0)
          f3 << (fs[2] || 0.0)
        end

        f1 = [0.0] if f1.empty?

        fric_frames = (parts[:burst]...vs).to_a
        fric_frames = [parts[:burst]] if fric_frames.empty?
        moments = fric_frames.map do |i|
          DSP::SpectralMoments.of(an[:powers][i], sample_rate: sr, size: an[:nfft])
        end

        centroid = DTW::Statistics.mean(moments.map(&:centroid))
        spread = DTW::Statistics.mean(moments.map(&:spread))
        skewness = DTW::Statistics.mean(moments.map(&:skewness))
        kurtosis = DTW::Statistics.mean(moments.map(&:kurtosis))

        tail_start = ve - ((ve - vs) / 3.0).round
        tail = (tail_start..ve).to_a
        tail = [ve] if tail.empty?
        nasal = DTW::Statistics.mean(tail.map { |i| low_band_ratio(an[:powers][i], sr, an[:nfft], 500.0) })
        mid = ((vs + ve) / 2)
        nasal_mid = low_band_ratio(an[:powers][mid] || an[:powers][vs], sr, an[:nfft], 500.0)

        n_band = tail.sum { |i| band_energy(an[:powers][i], sr, an[:nfft], 1400.0, 2400.0) }
        ng_band = tail.sum { |i| band_energy(an[:powers][i], sr, an[:nfft], 2600.0, 3600.0) }
        nasal_antiformant = if (n_band + ng_band).positive?
          10.0 * Math.log10((n_band + 1e-12) / (ng_band + 1e-12))
        else
          0.0
        end

        energy_curve = DSP::Curve.resample((lo..hi).map { |i| an[:energy][i] }, TONE_POINTS)

        f1 = median_filter(f1)
        f2 = median_filter(f2)
        f3 = median_filter(f3)

        f1c = DSP::Curve.resample(f1, FORMANT_POINTS)
        f2c = DSP::Curve.resample(f2.empty? ? [0.0] : f2, FORMANT_POINTS)
        f3c = DSP::Curve.resample(f3.empty? ? [0.0] : f3, FORMANT_POINTS)
        f1m = mid_of(f1c)
        f2m = mid_of(f2c)
        f3m = mid_of(f3c)

        f3_valid = f3.select { |v| v > 1500.0 }
        scale = f3_valid.length >= 3 ? DTW::Statistics.median(f3_valid) : (f3m && f3m > 1500.0 ? f3m : nil)

        f2_end = f2c[(FORMANT_POINTS * 0.85).floor]
        f1_end = f1c[(FORMANT_POINTS * 0.85).floor]
        f1_on = f1c[ONSET_POINT]
        f2_on = f2c[ONSET_POINT]
        f1v = window_median(f1c, VOWEL_WINDOW)
        f2v = window_median(f2c, VOWEL_WINDOW)
        vowel_ok = formants_reliable?(scale && f1v && f1v / scale, scale && f2v && f2v / scale)
        f1_ratio = scale ? f1m / scale : nil
        f2_ratio = scale ? f2m / scale : nil

        {
          "f1_mid" => f1m,
          "f2_mid" => f2m,
          "f3_mid" => f3m,
          "f2_end" => f2_end,
          "f1_onset" => f1_on,
          "f2_onset" => f2_on,
          "f2_over_f1" => over(f2v, f1v),
          "f2_onset_ratio" => over(f2_on, f1_on),
          "f2_end_over_f1" => over(f2_end, f1v),
          "energy_tail_ratio" => tail_ratio(energy_curve),
          "formants_reliable" => vowel_ok,
          "f1_vowel" => f1v,
          "f2_vowel" => f2v,
          "f1_ratio" => f1_ratio,
          "f2_ratio" => f2_ratio,
          "f2_end_ratio" => scale ? f2_end / scale : nil,
          "f1_end_ratio" => scale ? f1_end / scale : nil,
          "f2_delta_ratio" => scale ? (f2_end - f2m) / scale : nil,
          "centroid_ratio" => scale && centroid > 0 ? centroid / scale : nil,
          "duration_ms" => (hi - lo + 1) * HOP_MS,
          "voiced_ms" => (ve - vs + 1) * HOP_MS,
          "voiced_ratio" => voiced_frames.to_f / total_frames,
          "f0_ref_hz" => ref,
          "tone_curve" => f0_curve,
          "tone_range" => (f0_curve.max - f0_curve.min),
          "tone_slope" => f0_curve.last - f0_curve.first,
          "mfcc" => mfcc_rs,
          "f1" => DSP::Curve.resample(f1, FORMANT_POINTS),
          "f2" => DSP::Curve.resample(f2.empty? ? [0.0] : f2, FORMANT_POINTS),
          "f3" => DSP::Curve.resample(f3.empty? ? [0.0] : f3, FORMANT_POINTS),
          "vot_ms" => parts[:vot_ms],
          "vot_ratio" => parts[:vot_valid] && duration_positive?(hi, lo) ? parts[:vot_ms] / ((hi - lo + 1) * HOP_MS) : nil,
          "vot_reliable" => parts[:vot_clean],
          "fric_centroid" => centroid,
          "fric_spread" => spread,
          "fric_skewness" => skewness,
          "fric_kurtosis" => kurtosis,
          "fric_ms" => (vs - lo) * HOP_MS,
          "nasal_ratio_tail" => nasal,
          "nasal_antiformant" => nasal_antiformant,
          "nasal_ratio_mid" => nasal_mid,
          "energy_curve" => energy_curve
        }
      end

      def window_median(curve, range)
        return nil if curve.nil? || curve.length < 8

        values = range.filter_map { |i| curve[i] }.select { |v| v.to_f > 0.0 }
        values.empty? ? nil : DTW::Statistics.median(values)
      end

      def over(value, base)
        return nil if value.nil? || base.nil? || base <= 0.0

        value / base
      end

      def tail_ratio(curve)
        return nil if curve.nil? || curve.length < 8

        tail = curve[(curve.length * TAIL_SHARE).floor..]
        body = curve[(curve.length * BODY_SHARE.begin).floor...(curve.length * BODY_SHARE.end).ceil]
        return nil if tail.blank? || body.blank?

        centre = body.sum / body.length
        centre.abs < 1e-9 ? nil : (tail.sum / tail.length) / centre
      end

      def formants_reliable?(f1_ratio, f2_ratio)
        return false if f1_ratio.nil? || f2_ratio.nil?
        return false if f1_ratio <= 0.0 || f2_ratio <= 0.0
        return false if f2_ratio >= FORMANT_MERGED

        f1_ratio / f2_ratio < FORMANT_F1_MERGED
      end

      def row_formants_reliable?(row)
        formants_reliable?(row["f1_ratio"], row["f2_ratio"])
      end

      def median_filter(v)
        return v if v.length < 3

        Array.new(v.length) do |i|
          a = v[[i - 1, 0].max]
          b = v[i]
          c = v[[i + 1, v.length - 1].min]
          [a, b, c].sort[1]
        end
      end

      def duration_positive?(hi, lo)
        (hi - lo + 1) * HOP_MS > 1.0
      end

      def mid_of(curve)
        return nil if curve.nil? || curve.empty?

        curve[curve.length / 2]
      end

      def band_energy(power, sr, nfft, lo_hz, hi_hz)
        return 0.0 unless power

        acc = 0.0
        k = 0
        while k < power.length
          f = k.to_f * sr / nfft
          acc += power[k] if f >= lo_hz && f <= hi_hz
          k += 1
        end

        acc
      end

      def low_band_ratio(power, sr, nfft, cutoff)
        return 0.0 unless power

        lo = 0.0
        total = 0.0
        k = 0
        while k < power.length
          f = k.to_f * sr / nfft
          next_k = k + 1
          if f > 80.0
            total += power[k]
            lo += power[k] if f <= cutoff
          end

          k = next_k
        end

        total <= 1e-15 ? 0.0 : lo / total
      end

      OCTAVE_DRIFT_ST = 9.0

      def octave_aligned(track, reference)
        return track unless reference.to_f > 50.0

        voiced = track.select { |v| v > 0.0 }
        return track if voiced.length < 3

        drift = DSP::Scales.hz_to_semitones(DTW::Statistics.median(voiced), reference: reference)
        return track if drift.abs <= OCTAVE_DRIFT_ST

        factor = drift.positive? ? 0.5 : 2.0
        track.map { |v| v > 0.0 ? v * factor : v }
      end

      MAX_SEMITONE_JUMP = 2.5
      OCTAVE_TOLERANCE = 4.0

      def clean_f0_track(track)
        voiced = track.each_with_index.select { |v, _i| v > 0 }
        return track if voiced.length < 3

        out = track.dup
        values = voiced.map(&:first)
        med = DTW::Statistics.median(values)
        return track if med <= 0

        voiced.each do |(v, i)|
          st = DSP::Scales.hz_to_semitones(v, reference: med)
          next if st.abs < 12.0 - OCTAVE_TOLERANCE

          cand = [v, v * 2.0, v / 2.0].min_by { |c| DSP::Scales.hz_to_semitones(c, reference: med).abs }
          out[i] = if DSP::Scales.hz_to_semitones(cand, reference: med).abs < 12.0 - OCTAVE_TOLERANCE
            cand
          else
            0.0
          end
        end

        idx = out.each_with_index.select { |v, _i| v > 0 }.map(&:last)
        return out if idx.length < 3

        anchor = idx[idx.length / 2]
        [idx.select { |i| i >= anchor }, idx.select { |i| i <= anchor }.reverse].each do |seq|
          prev = out[seq.first]
          seq.each do |i|
            next if out[i] <= 0

            jump = DSP::Scales.hz_to_semitones(out[i], reference: prev).abs
            if jump > MAX_SEMITONE_JUMP
              out[i] = 0.0
            else
              prev = out[i]
            end
          end
        end

        out
      end

      def fill_gaps(v, max_gap = 4)
        out = v.dup
        i = 0
        while i < out.length
          if out[i] <= 0
            j = i
            j += 1 while j < out.length && out[j] <= 0
            left = i > 0 ? out[i - 1] : 0.0
            right = j < out.length ? out[j] : 0.0
            if (j - i) <= max_gap && left > 0 && right > 0
              (i...j).each do |k|
                t = (k - i + 1).to_f / (j - i + 1)
                out[k] = (left * (1 - t)) + (right * t)
              end
            end

            i = j
          else
            i += 1
          end
        end

        out
      end

      def resample_matrix(rows, n)
        return Array.new(n) { Array.new(N_MFCC, 0.0) } if rows.empty?

        dim = rows[0].length
        cols = (0...dim).map { |d| DSP::Curve.resample(rows.map { |r| r[d] }, n) }
        Array.new(n) { |i| Array.new(dim) { |d| cols[d][i] } }
      end
    end
  end
end
