# frozen_string_literal: true

module Pronunciation
  class WarmupAnalysis
    MIN_VOICED_FRAMES = 20
    F3_FLOOR = 1500.0

    def call(audio, f0_low: nil)
      samples, rate = decode(audio)
      return nil if samples.nil? || samples.empty?

      analysis = Acoustic::Features.analyze(samples, rate, f0_floor: Acoustic::Features.floor_for(f0_low))
      low, high = Acoustic::Features.speech_bounds(analysis)
      return nil unless low && high && high > low

      voiced = (low..high).filter_map { |i| analysis[:f0][i] if analysis[:f0][i].to_f > 0 }
      return nil if voiced.length < MIN_VOICED_FRAMES

      {f0_voiced: voiced}.merge(formants(analysis, low, high, rate))
    rescue StandardError
      nil
    end

    private

    def formants(analysis, low, high, rate)
      win = analysis[:win]
      hop = analysis[:hop]
      collected = {f1: [], f2: [], f3: []}
      extractor = Acoustic::Features.formant_extractor(
        rate,
        analysis[:max_formant] || DSP::Formants::DEFAULT_MAXIMUM_HZ
      )

      (low..high).each do |i|
        start = i * hop
        break if start + win > analysis[:samples].length
        next unless analysis[:f0][i].to_f > 0

        values = extractor.call(
          DSP::Waveform.new(samples: analysis[:samples][start, win], sample_rate: rate)
        )
        collected[:f1] << values[0] if values[0].to_f > 0
        collected[:f2] << values[1] if values[1].to_f > 0
        collected[:f3] << values[2] if values[2].to_f > F3_FLOOR
      end

      {
        f1_median: median(collected[:f1]),
        f2_median: median(collected[:f2]),
        f3_median: median(collected[:f3])
      }.compact
    end

    def median(values)
      return nil if values.length < 5

      DTW::Statistics.median(values)
    end

    def decode(audio) = Recording.decode(audio)
  end
end
