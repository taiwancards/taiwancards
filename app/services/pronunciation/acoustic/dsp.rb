# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Dsp
      module_function

      def read_wav(path)
        parse_wav(File.binread(path))
      end

      def parse_wav(bytes)
        raise "not a WAV (no RIFF/WAVE header)" unless bytes[0, 4] == "RIFF" && bytes[8, 4] == "WAVE"

        pos = 12
        sample_rate = nil
        channels = 1
        bits = 16
        data = nil

        while pos + 8 <= bytes.bytesize
          id = bytes[pos, 4]
          size = bytes[pos + 4, 4].unpack1("V")
          body = bytes[pos + 8, size]
          case id
          when "fmt "
            _fmt, channels, sample_rate, _brate, _align, bits = body.unpack("vvVVvv")
          when "data"
            data = body
          end

          pos += 8 + size + (size.odd? ? 1 : 0)
        end

        raise "no data chunk in the WAV" if data.nil? || sample_rate.nil?
        raise "expected 16 bit, got #{bits}" unless bits == 16

        samples = data.unpack("s<*").map { |v| v / 32_768.0 }
        if channels > 1
          mono = Array.new(samples.length / channels, 0.0)
          i = 0
          while i < mono.length
            acc = 0.0
            c = 0
            while c < channels
              acc += samples[(i * channels) + c]
              c += 1
            end

            mono[i] = acc / channels
            i += 1
          end

          samples = mono
        end

        [samples, sample_rate]
      end

      TWIDDLE = {}

      def twiddles(len)
        TWIDDLE[len] ||= begin
          half = len / 2
          cos = Array.new(half, 0.0)
          sin = Array.new(half, 0.0)
          k = 0
          while k < half
            ang = -2.0 * Math::PI * k / len
            cos[k] = Math.cos(ang)
            sin[k] = Math.sin(ang)
            k += 1
          end

          [cos, sin]
        end
      end

      def fft!(re, im)
        n = re.length
        raise "FFT length must be a power of two" unless n & (n - 1) == 0

        j = 0
        i = 1
        while i < n
          bit = n >> 1
          while (j & bit) != 0
            j ^= bit
            bit >>= 1
          end

          j |= bit
          if i < j
            re[i], re[j] = re[j], re[i]
            im[i], im[j] = im[j], im[i]
          end

          i += 1
        end

        len = 2
        while len <= n
          cos, sin = twiddles(len)
          half = len / 2
          i = 0
          while i < n
            k = 0
            while k < half
              wr = cos[k]
              wi = sin[k]
              a = i + k
              b = a + half
              xr = re[b]
              xi = im[b]
              tr = (xr * wr) - (xi * wi)
              ti = (xr * wi) + (xi * wr)
              re[b] = re[a] - tr
              im[b] = im[a] - ti
              re[a] += tr
              im[a] += ti
              k += 1
            end

            i += len
          end

          len <<= 1
        end

        [re, im]
      end

      def power_spectrum(frame, nfft)
        re = Array.new(nfft, 0.0)
        im = Array.new(nfft, 0.0)
        n = [frame.length, nfft].min
        i = 0
        while i < n
          re[i] = frame[i]
          i += 1
        end

        fft!(re, im)
        half = (nfft / 2) + 1
        out = Array.new(half, 0.0)
        i = 0
        while i < half
          out[i] = (re[i] * re[i]) + (im[i] * im[i])
          i += 1
        end

        out
      end

      HAMMING = {}

      def hamming(n)
        HAMMING[n] ||= Array.new(n) { |i| 0.54 - (0.46 * Math.cos(2.0 * Math::PI * i / (n - 1))) }
      end

      def preemphasis(x, coef = 0.97)
        out = Array.new(x.length, 0.0)
        out[0] = x[0]
        i = 1
        while i < x.length
          out[i] = x[i] - (coef * x[i - 1])
          i += 1
        end

        out
      end

      def frames(x, win, hop)
        out = []
        i = 0
        while i + win <= x.length
          out << x[i, win]
          i += hop
        end

        out
      end

      def hz_to_mel(f) = 2595.0 * Math.log10(1.0 + (f / 700.0))
      def mel_to_hz(m) = 700.0 * ((10.0 ** (m / 2595.0)) - 1.0)

      FILTERBANK = {}

      def mel_filterbank(sr, nfft, n_filters = 26, fmin = 50.0, fmax = nil, warp = 1.0)
        fmax ||= sr / 2.0
        warp = (warp * 50).round / 50.0
        key = [sr, nfft, n_filters, fmin, fmax, warp]
        FILTERBANK[key] ||= begin
          lo = hz_to_mel(fmin)
          hi = hz_to_mel(fmax)
          points = Array.new(n_filters + 2) { |i| mel_to_hz(lo + ((hi - lo) * i / (n_filters + 1))) * warp }
          bins = points.map { |f| ((nfft + 1) * f / sr).floor }
          half = (nfft / 2) + 1

          (0...n_filters).map do |m|
            left, center, right = bins[m], bins[m + 1], bins[m + 2]
            left = [left, 0].max
            right = [right, half - 1].min
            center = [[center, left + 1].max, right - 1].min
            weights = []
            (left..right).each do |k|
              weights <<
                if k < center
                  (k - left).to_f / [center - left, 1].max
                elsif k == center
                  1.0
                else
                  (right - k).to_f / [right - center, 1].max
                end
            end

            [left, weights]
          end
        end
      end

      def dct2(v, n_out)
        m = v.length
        Array.new(n_out) do |k|
          acc = 0.0
          i = 0
          while i < m
            acc += v[i] * Math.cos(Math::PI * k * (i + 0.5) / m)
            i += 1
          end

          acc
        end
      end

      def mfcc_from_power(power, bank, n_coeffs = 13)
        energies = bank.map do |(offset, w)|
          acc = 0.0
          k = 0
          len = w.length
          while k < len
            acc += w[k] * power[offset + k]
            k += 1
          end

          Math.log([acc, 1e-12].max)
        end

        dct2(energies, n_coeffs)
      end

      def yin(x, sr, fmin: 70.0, fmax: 500.0, hop_seconds: 0.008, threshold: 0.15)
        factor = [(sr / 5512.5).floor, 1].max
        xs, srs = factor > 1 ? decimate(x, sr, factor) : [x, sr]

        tau_min = (srs / fmax).floor.clamp(2, 10_000)
        tau_max = (srs / fmin).ceil.clamp(tau_min + 2, 10_000)
        win = tau_max * 2
        hop = [(srs * hop_seconds).round, 1].max

        f0 = []
        conf = []
        times = []

        pos = 0
        while pos + win + tau_max <= xs.length
          d = Array.new(tau_max + 1, 0.0)
          tau = tau_min
          while tau <= tau_max
            acc = 0.0
            j = 0
            while j < win
              diff = xs[pos + j] - xs[pos + j + tau]
              acc += diff * diff
              j += 1
            end

            d[tau] = acc
            tau += 1
          end

          dn = Array.new(tau_max + 1, 1.0)
          run = 0.0
          tau = tau_min
          while tau <= tau_max
            run += d[tau]
            dn[tau] = run.zero? ? 1.0 : d[tau] * (tau - tau_min + 1) / run
            tau += 1
          end

          best = nil
          tau = tau_min + 1
          while tau < tau_max
            if dn[tau] < threshold && dn[tau] <= dn[tau + 1]
              best = tau
              break
            end

            tau += 1
          end

          if best.nil?
            mn = 1e18
            tau = tau_min
            while tau <= tau_max
              if dn[tau] < mn
                mn = dn[tau]
                best = tau
              end

              tau += 1
            end
          end

          if best && best > tau_min && best < tau_max
            y1 = dn[best - 1]
            y2 = dn[best]
            y3 = dn[best + 1]
            denom = (2.0 * y2) - y1 - y3
            shift = denom.abs < 1e-12 ? 0.0 : 0.5 * (y3 - y1) / denom
            period = best + shift
            value = dn[best]
            freq = srs / period
            voiced = value < 0.35 && freq >= fmin && freq <= fmax
            f0 << (voiced ? freq : 0.0)
            conf << (voiced ? (1.0 - value).clamp(0.0, 1.0) : 0.0)
          else
            f0 << 0.0
            conf << 0.0
          end

          times << (pos.to_f / srs)
          pos += hop
        end

        {f0: f0, confidence: conf, times: times, hop_seconds: hop.to_f / srs}
      end

      def decimate(x, sr, factor)
        cutoff = 0.45 / factor
        taps = 31
        mid = (taps - 1) / 2
        h = Array.new(taps) do |i|
          n = i - mid
          sinc = n.zero? ? (2.0 * cutoff) : Math.sin(2.0 * Math::PI * cutoff * n) / (Math::PI * n)
          sinc * (0.54 - (0.46 * Math.cos(2.0 * Math::PI * i / (taps - 1))))
        end

        norm = h.sum
        h = h.map { |v| v / norm }

        out = []
        i = 0
        while i < x.length
          acc = 0.0
          k = 0
          while k < taps
            idx = i + k - mid
            acc += h[k] * x[idx] if idx >= 0 && idx < x.length
            k += 1
          end

          out << acc
          i += factor
        end

        [out, sr.to_f / factor]
      end

      def autocorrelation(frame, order)
        n = frame.length
        Array.new(order + 1) do |lag|
          acc = 0.0
          i = 0
          while i < n - lag
            acc += frame[i] * frame[i + lag]
            i += 1
          end

          acc
        end
      end

      def levinson(r, order)
        a = Array.new(order + 1, 0.0)
        a[0] = 1.0
        err = r[0]
        return [a, 0.0] if err <= 0.0

        (1..order).each do |i|
          acc = r[i]
          (1...i).each { |j| acc += a[j] * r[i - j] }
          k = -acc / err
          return [a, err] if k.abs >= 1.0

          new_a = a.dup
          (1...i).each { |j| new_a[j] = a[j] + (k * a[i - j]) }
          new_a[i] = k
          a = new_a
          err *= 1.0 - (k * k)
          return [a, err] if err <= 0.0
        end

        [a, err]
      end

      def formants(frame, sr, max_formant: 5500.0, n_formants: 4)
        factor = [(sr / (2.0 * max_formant)).round, 1].max
        xs, srs = factor > 1 ? decimate(frame, sr, factor) : [frame, sr]
        return [] if xs.length < 40

        order = (2 * n_formants) + 2
        win = hamming(xs.length)
        w = Array.new(xs.length) { |i| xs[i] * win[i] }
        w = preemphasis(w, 0.97)

        r = autocorrelation(w, order)
        return [] if r[0] <= 1e-10

        a, = levinson(r, order)

        npts = 512
        mag = Array.new(npts, 0.0)
        idx = 0
        while idx < npts
          omega = Math::PI * idx / (npts - 1)
          sr_re = 0.0
          sr_im = 0.0
          k = 0
          while k <= order
            ang = -omega * k
            sr_re += a[k] * Math.cos(ang)
            sr_im += a[k] * Math.sin(ang)
            k += 1
          end

          denom = (sr_re * sr_re) + (sr_im * sr_im)
          mag[idx] = denom < 1e-18 ? 1e9 : 1.0 / denom
          idx += 1
        end

        peaks = []
        i = 1
        while i < npts - 1
          if mag[i] > mag[i - 1] && mag[i] >= mag[i + 1]
            y1 = Math.log(mag[i - 1] + 1e-18)
            y2 = Math.log(mag[i] + 1e-18)
            y3 = Math.log(mag[i + 1] + 1e-18)
            denom = (2.0 * y2) - y1 - y3
            shift = denom.abs < 1e-12 ? 0.0 : 0.5 * (y3 - y1) / denom
            pos = i + shift
            freq = (srs / 2.0) * pos / (npts - 1)
            peaks << [freq, y2] if freq > 150.0 && freq < (srs / 2.0) - 150.0
          end

          i += 1
        end

        merged = []
        peaks.sort_by! { |(f, _)| f }
        peaks.each do |(f, amp)|
          if merged.any? && (f - merged.last[0]) < 250.0
            merged[-1] = [f, amp] if amp > merged.last[1]
          else
            merged << [f, amp]
          end
        end

        merged.map(&:first).first(n_formants)
      end

      def spectral_moments(power, sr, nfft, fmin: 500.0, fmax: nil)
        fmax ||= (sr / 2.0) - 200.0
        total = 0.0
        c = 0.0
        freqs = []
        weights = []
        k = 0
        while k < power.length
          f = k.to_f * sr / nfft
          if f >= fmin && f <= fmax
            p = power[k]
            freqs << f
            weights << p
            total += p
            c += f * p
          end

          k += 1
        end

        return {centroid: 0.0, spread: 0.0, skewness: 0.0, kurtosis: 0.0} if total <= 1e-12

        centroid = c / total
        m2 = 0.0
        m3 = 0.0
        m4 = 0.0
        i = 0
        while i < freqs.length
          dv = freqs[i] - centroid
          w = weights[i]
          m2 += w * dv * dv
          m3 += w * dv * dv * dv
          m4 += w * dv * dv * dv * dv
          i += 1
        end

        m2 /= total
        m3 /= total
        m4 /= total
        sd = Math.sqrt([m2, 1e-12].max)
        {
          centroid: centroid,
          spread: sd,
          skewness: m3 / (sd ** 3),
          kurtosis: (m4 / (sd ** 4)) - 3.0
        }
      end

      def frame_energy_db(frame)
        acc = 0.0
        i = 0
        while i < frame.length
          acc += frame[i] * frame[i]
          i += 1
        end

        10.0 * Math.log10((acc / frame.length) + 1e-12)
      end

      def zero_crossing_rate(frame)
        cnt = 0
        i = 1
        while i < frame.length
          cnt += 1 if (frame[i] >= 0) != (frame[i - 1] >= 0)
          i += 1
        end

        cnt.to_f / (frame.length - 1)
      end

      def biquad(x, coeffs)
        b0, b1, b2, a1, a2 = coeffs
        z1 = 0.0
        z2 = 0.0
        out = Array.new(x.length, 0.0)
        i = 0
        while i < x.length
          v = x[i]
          y = (b0 * v) + z1
          z1 = (b1 * v) - (a1 * y) + z2
          z2 = (b2 * v) - (a2 * y)
          out[i] = y
          i += 1
        end

        out
      end

      def butter_coeffs(sr, hz, high:)
        w = 2.0 * Math::PI * (hz.to_f / sr).clamp(1e-4, 0.49)
        cos = Math.cos(w)
        alpha = Math.sin(w) / Math.sqrt(2.0)
        a0 = 1.0 + alpha

        b = if high
          [(1.0 + cos) / 2.0, -(1.0 + cos), (1.0 + cos) / 2.0]
        else
          [(1.0 - cos) / 2.0, 1.0 - cos, (1.0 - cos) / 2.0]
        end

        [b[0] / a0, b[1] / a0, b[2] / a0, (-2.0 * cos) / a0, (1.0 - alpha) / a0]
      end

      def lowpass(x, sr, hz, order: 2)
        coeffs = butter_coeffs(sr, hz, high: false)
        order.times.reduce(x) { |acc, _| biquad(acc, coeffs) }
      end

      def highpass(x, sr, hz, order: 2)
        coeffs = butter_coeffs(sr, hz, high: true)
        order.times.reduce(x) { |acc, _| biquad(acc, coeffs) }
      end

      def envelope_db(x, win, hop)
        return [] if x.length < win || win < 1 || hop < 1

        acc = 0.0
        i = 0
        while i < win
          acc += x[i] * x[i]
          i += 1
        end

        out = [10.0 * Math.log10((acc / win) + 1e-12)]
        pos = hop
        while pos + win <= x.length
          j = pos - hop
          while j < pos
            acc -= x[j] * x[j]
            acc += x[j + win] * x[j + win]
            j += 1
          end

          out << (10.0 * Math.log10(([acc, 0.0].max / win) + 1e-12))
          pos += hop
        end

        out
      end

      def semitones(f, ref) = 12.0 * Math.log2(f / ref)

      def resample_curve(v, n)
        return Array.new(n, 0.0) if v.empty?
        return Array.new(n, v[0]) if v.length == 1

        Array.new(n) do |i|
          x = i.to_f * (v.length - 1) / (n - 1)
          lo = x.floor
          hi = [lo + 1, v.length - 1].min
          frac = x - lo
          (v[lo] * (1 - frac)) + (v[hi] * frac)
        end
      end

      def median(arr)
        return 0.0 if arr.empty?

        s = arr.sort
        m = s.length / 2
        s.length.odd? ? s[m] : 0.5 * (s[m - 1] + s[m])
      end

      def mean(arr) = arr.empty? ? 0.0 : arr.sum / arr.length.to_f

      def stddev(arr)
        return 0.0 if arr.length < 2

        m = mean(arr)
        Math.sqrt(arr.sum { |v| (v - m) ** 2 } / (arr.length - 1).to_f)
      end
    end
  end
end
