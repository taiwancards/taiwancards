# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Quality
      FLATNESS_LOW_HZ = 200.0
      FLATNESS_HIGH_HZ = 4000.0
      HUM_HZ = 80.0
      CORE_LOW_HZ = 300.0
      CORE_HIGH_HZ = 3400.0
      DIGITAL_SILENCE_DB = -95.0
      VOICED_CONFIDENCE = 0.5
      CLIP_LEVEL = 0.985
      MIN_VOICED_FRAMES = 5
      SAMPLED_FRAMES = 40
      QUIET_PERCENTILE = 0.25
      SCALE = 1000.0

      module_function

      def of(an)
        voiced = (0...an[:n]).select { |i| an[:conf][i].to_f > VOICED_CONFIDENCE }
        return {} if voiced.length < MIN_VOICED_FRAMES

        levels = voiced.map { |i| an[:energy][i] }
        spectral = spectral_measures(an, voiced)

        {
          "flatness" => spectral[:flatness],
          "hum_share" => spectral[:hum_share],
          "core_share" => spectral[:core_share],
          "snr_db" => snr_db(an, levels),
          "pitch_conf" => DTW::Statistics.median(voiced.map { |i| an[:conf][i].to_f }).round(3),
          "level_db" => DTW::Statistics.median(levels).round(2),
          "clip_share" => clip_share(an[:samples]),
          "n_voiced" => voiced.length
        }
      end

      def spectral_measures(an, voiced)
        step = [voiced.length / SAMPLED_FRAMES, 1].max
        bin_hz = an[:sr] / an[:nfft].to_f
        low = (FLATNESS_LOW_HZ / bin_hz).round
        high = (FLATNESS_HIGH_HZ / bin_hz).round
        flats = []
        total = 0.0
        hum = 0.0
        core = 0.0

        voiced.each_slice(step) do |chunk|
          power = an[:powers][chunk.first]
          next if power.nil?

          flats << flatness_of(power, low, high)
          total += power.sum
          hum += band_sum(power, 0, (HUM_HZ / bin_hz).floor)
          core += band_sum(power, (CORE_LOW_HZ / bin_hz).floor, (CORE_HIGH_HZ / bin_hz).ceil)
        end

        measured = flats.compact
        {
          flatness: measured.empty? ? nil : (DTW::Statistics.median(measured) * SCALE).round(3),
          hum_share: total.positive? ? (hum / total).round(5) : nil,
          core_share: total.positive? ? (core / total).round(4) : nil
        }
      end

      def flatness_of(power, low, high)
        band = power[low..high]
        return nil if band.nil? || band.length < 4

        arithmetic = band.sum / band.length
        return nil unless arithmetic.positive?

        geometric = Math.exp(band.sum { |value| Math.log(value + Float::MIN) } / band.length)
        geometric / arithmetic
      end

      def band_sum(power, low, high)
        top = [high, power.length - 1].min
        low > top ? 0.0 : power[low..top].sum
      end

      def snr_db(an, levels)
        speech = DTW::Statistics.median(levels)
        quiet = (0...an[:n])
          .reject { |i| an[:conf][i].to_f > VOICED_CONFIDENCE }
          .map { |i| an[:energy][i] }
          .select { |value| value > DIGITAL_SILENCE_DB }
        return nil if quiet.empty?

        sorted = quiet.sort
        (speech - sorted[(sorted.length * QUIET_PERCENTILE).floor]).round(2)
      end

      def clip_share(samples)
        clipped = 0
        index = 0
        while index < samples.length
          clipped += 1 if samples[index].abs >= CLIP_LEVEL
          index += 1
        end

        (clipped.to_f / samples.length).round(6)
      end
    end
  end
end
