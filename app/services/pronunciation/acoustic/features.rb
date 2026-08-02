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
      MFCC_POINTS = 12

      module_function

      CANONICAL_F3 = 3000.0

      def analyze(samples, sr, speaker_f3: nil)
        win = (sr * FRAME_MS / 1000.0).round
        hop = (sr * HOP_MS / 1000.0).round
        window = DSP::Window.hamming(win)
        spectrum = DSP::Spectrum.new(NFFT)

        powers = []
        energy = []
        zcr = []
        centers = []

        pos = 0
        while pos + win <= samples.length
          raw = samples[pos, win]
          energy << DSP::Energy.frame_db(raw)
          zcr << DSP::Energy.zero_crossing_rate(raw)

          pre = DSP::Framing.preemphasis(raw, coefficient: 0.97)
          wf = Array.new(win) { |i| pre[i] * window[i] }
          powers << spectrum.power(wf)

          centers << ((pos + (win / 2.0)) / sr)
          pos += hop
        end

        f3_est = speaker_f3 || estimate_f3(samples, sr, win, hop, energy)
        warp = f3_est ? (f3_est / CANONICAL_F3).clamp(0.75, 1.35) : 1.0
        max_formant = 5500.0 * warp

        bank = DSP::MelFilterbank.new(sample_rate: sr, size: NFFT, filters: N_MEL, low: 50.0, warp: warp)
        mfcc = DSP::Mfcc.new(filterbank: bank, coefficients: N_MFCC, spectrum: spectrum)
        mfccs = powers.map { |pw| mfcc.call(pw) }

        speech_lo, speech_hi = energy_bounds(energy)
        if speech_hi > speech_lo
          mean = Array.new(N_MFCC, 0.0)
          cnt = 0
          (speech_lo..speech_hi).each do |i|
            row = mfccs[i]
            next unless row

            d = 0
            while d < N_MFCC
              mean[d] += row[d]
              d += 1
            end

            cnt += 1
          end

          if cnt.positive?
            mean.map! { |v| v / cnt }
            mfccs = mfccs.map { |row| Array.new(N_MFCC) { |d| row[d] - mean[d] } }
          end
        end

        pitch = DSP::Yin.new(hop_seconds: HOP_MS / 1000.0).call(waveform_of(samples, sr))
        yin_win_offset = 0.0
        yin_centers = pitch.times.map { |t| t + yin_win_offset }

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

      # The predictor has a fixed order, so the analysis band has to stay near the ceiling it was
      # sized for: decimate to the rate closest to twice the ceiling, not to the first rate above it.
      def formant_extractor(sr, ceiling)
        factor = [(sr / (2.0 * ceiling)).round, 1].max
        DSP::Formants.new(maximum_frequency: sr / (2.0 * factor))
      end

      def estimate_f3(samples, sr, win, hop, energy)
        return nil if energy.empty?

        sorted = energy.compact.sort
        thr = sorted[(sorted.length * 0.6).to_i]
        extractor = formant_extractor(sr, DSP::Formants::DEFAULT_MAXIMUM_HZ)
        vals = []
        energy.each_with_index do |e, i|
          next if e.nil? || e < thr

          start = i * hop
          break if start + win > samples.length

          f = extractor.call(waveform_of(samples[start, win], sr))[2]
          vals << f if f && f > 1800 && f < 4200
        end

        return nil if vals.length < 5

        vals.sort[vals.length / 2]
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

        audible = e.reject { |v| v <= SILENCE_DB }
        sorted = (audible.length >= 3 ? audible : e).sort
        floor = sorted[(sorted.length * 0.10).floor]
        peak = sorted[(sorted.length * 0.95).floor]
        thr = [floor + NOISE_MARGIN_DB, peak - PEAK_WINDOW_DB].max
        thr = [thr, peak - MIN_HEADROOM_DB].min

        first = e.index { |v| v > thr }
        last = e.rindex { |v| v > thr }
        return [0, an[:n] - 1] if first.nil? || last.nil?

        first = past_transient(e, first, last, thr)

        back = [(150.0 / HOP_MS).round, first].min
        burst = first
        (1..back).each do |k|
          i = first - k
          break if i < 1

          rise = e[i] - e[i - 1]
          burst = i if rise > 6.0 && e[i] > floor + 4.0
        end

        [burst, last]
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

      def syllable_spans(an, n_syllables)
        lo, hi = speech_bounds(an)
        return nil if hi - lo < 4

        return [[lo, hi]] if n_syllables == 1

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

      def forced_spans(an, n_syllables)
        lo, hi = speech_bounds(an)
        length = hi - lo + 1
        return nil if length < n_syllables * 3

        son = smooth(an[:energy][lo..hi])
        reach = [(length / (n_syllables * 2.0)).floor, 3].max
        bounds = [0]
        (1...n_syllables).each do |k|
          target = (length * k / n_syllables.to_f).round
          a = [target - reach, bounds.last + 2].max
          b = [target + reach, length - 2].min
          bounds << (a > b ? target.clamp(1, length - 2) : (a..b).min_by { |i| son[i] })
        end

        bounds << length - 1

        (0...n_syllables).map { |i| [lo + bounds[i], lo + bounds[i + 1]] }
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

      def noise_floor(an)
        e = an[:energy]
        audible = e.reject { |v| v <= SILENCE_DB }
        sorted = (audible.length >= 3 ? audible : e).sort
        sorted[(sorted.length * 0.10).floor]
      end

      def lead_in?(an, span)
        e = an[:energy]
        needed = (LEAD_IN_MS / HOP_MS).round
        start = span[0]
        return false if start < needed

        limit = noise_floor(an) + QUIET_START_DB
        e[(start - needed)...start].all? { |v| v < limit }
      end

      def fine_onset(an, span, initial, utterance_initial)
        return nil unless utterance_initial
        return nil unless Phonology.obstruent?(initial)

        clean = lead_in?(an, span)
        hop = an[:hop]
        fine = Onset.measure(
          an[:samples],
          an[:sr],
          span[0] * hop,
          (span[1] + 1) * hop,
          back_ms: clean ? BACK_SEARCH_MS : 0.0,
          from_edge: !clean
        )
        return nil unless fine && Onset.plausible?(fine[:vot_ms], from_edge: !clean)

        fine.merge(clean: clean)
      end

      # No Mandarin syllable carries this much aspiration or frication around its voiced core
      # (both sit at the 99th percentile of the corpus), so anything further out is room noise.
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

        {
          "f1_mid" => f1m,
          "f2_mid" => f2m,
          "f3_mid" => f3m,
          "f2_end" => f2_end,
          "f1_ratio" => scale ? f1m / scale : nil,
          "f2_ratio" => scale ? f2m / scale : nil,
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

      # A whole syllable sitting an octave off is the pitch tracker halving or doubling, not a
      # speaker leaping out of their own range, so the track moves as one and its shape survives.
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
