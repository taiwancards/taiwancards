# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Dtw
      module_function

      def dist(a, b)
        acc = 0.0
        i = 0
        while i < a.length
          d = a[i] - b[i]
          acc += d * d
          i += 1
        end

        Math.sqrt(acc)
      end

      def align(a, b, band_ratio: 0.25)
        n = a.length
        m = b.length
        return [Float::INFINITY, []] if n.zero? || m.zero?

        band = [(band_ratio * [n, m].max).ceil, (n - m).abs + 1].max
        inf = Float::INFINITY
        cost = Array.new(n + 1) { Array.new(m + 1, inf) }
        cost[0][0] = 0.0

        i = 1
        while i <= n
          jlo = [1, i - band].max
          jhi = [m, i + band].min
          j = jlo
          while j <= jhi
            d = dist(a[i - 1], b[j - 1])
            best = cost[i - 1][j]
            v = cost[i][j - 1]
            best = v if v < best
            v = cost[i - 1][j - 1]
            best = v if v < best
            cost[i][j] = d + best
            j += 1
          end

          i += 1
        end

        path = []
        i = n
        j = m
        while i > 0 && j > 0
          path << [i - 1, j - 1]
          diag = cost[i - 1][j - 1]
          up = cost[i - 1][j]
          left = cost[i][j - 1]
          if diag <= up && diag <= left
            i -= 1
            j -= 1
          elsif up <= left
            i -= 1
          else
            j -= 1
          end
        end

        path.reverse!
        [cost[n][m] / [path.length, 1].max, path]
      end

      def distance(a, b, band_ratio: 0.25)
        align(a, b, band_ratio: band_ratio)[0]
      end

      def barycenter(sequences, length: nil, iterations: 4)
        seqs = sequences.reject { |s| s.nil? || s.empty? }
        return nil if seqs.empty?

        dim = seqs[0][0].length
        length ||= (seqs.sum(&:length).to_f / seqs.length).round.clamp(4, 40)

        init = medoid(seqs)
        center = resize(init, length)

        iterations.times do
          buckets = Array.new(length) { Array.new(dim) { [] } }
          seqs.each do |s|
            _c, path = align(center, s)
            path.each do |(ci, si)|
              d = 0
              while d < dim
                buckets[ci][d] << s[si][d]
                d += 1
              end
            end
          end

          new_center = Array.new(length) do |i|
            Array.new(dim) do |d|
              vals = buckets[i][d]
              vals.empty? ? center[i][d] : Dsp.median(vals)
            end
          end

          break if converged?(center, new_center)

          center = new_center
        end

        buckets = Array.new(length) { Array.new(dim) { [] } }
        seqs.each do |s|
          _c, path = align(center, s)
          path.each do |(ci, si)|
            d = 0
            while d < dim
              buckets[ci][d] << s[si][d]
              d += 1
            end
          end
        end

        sigma = Array.new(length) do |i|
          Array.new(dim) do |d|
            vals = buckets[i][d]
            mad(vals)
          end
        end

        {"center" => center, "sigma" => sigma, "n" => seqs.length, "length" => length}
      end

      def medoid(seqs)
        return seqs[0] if seqs.length <= 2

        sample = seqs.length > 12 ? seqs.each_slice((seqs.length / 12.0).ceil).map(&:first) : seqs
        best = nil
        best_cost = Float::INFINITY
        sample.each do |cand|
          c = sample.sum { |o| o.equal?(cand) ? 0.0 : distance(cand, o) }
          if c < best_cost
            best_cost = c
            best = cand
          end
        end

        best || seqs[0]
      end

      def resize(seq, n)
        dim = seq[0].length
        cols = (0...dim).map { |d| Dsp.resample_curve(seq.map { |v| v[d] }, n) }
        Array.new(n) { |i| Array.new(dim) { |d| cols[d][i] } }
      end

      def converged?(a, b, eps = 1e-4)
        return false if a.length != b.length

        total = 0.0
        a.each_index do |i|
          a[i].each_index { |d| total += (a[i][d] - b[i][d]).abs }
        end

        total / (a.length * a[0].length) < eps
      end

      def mad(vals)
        return 0.0 if vals.length < 2

        m = Dsp.median(vals)
        d = vals.map { |v| (v - m).abs }
        1.4826 * Dsp.median(d)
      end
    end
  end
end
