# frozen_string_literal: true

module Pronunciation
  module Recording
    CANONICAL_RATE = 22050

    module_function

    def decode(audio)
      bytes = audio.respond_to?(:read) ? audio.read : audio.to_s
      return [nil, nil] if bytes.blank?

      signal = narrowed(DSP.decode(bytes))
      [signal.samples, signal.sample_rate]
    end

    def narrowed(signal)
      return signal if DSP::Decimator.factor_for(signal.sample_rate, CANONICAL_RATE) <= 1

      DSP::Decimator.to(signal, CANONICAL_RATE)
    end
  end
end
