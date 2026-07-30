# frozen_string_literal: true

require "json"

module Pronunciation
  module AxisNorms
    PATH = "axis_norms.json"

    MIN_SPREAD = 0.35

    module_function

    def data
      @data ||= read
    end

    def reset! = @data = nil

    def read
      path = File.join(TemplateStore.instance.root, PATH)
      return {} unless File.exist?(path)

      JSON.parse(File.read(path))["axes"] || {}
    rescue JSON::ParserError
      {}
    end

    def for(id) = data[id.to_s]

    def calibrated? = data.any?

    SLOPE = 1.229
    MIDPOINT = 2.395

    def score(id, z)
      t = effective(id, z)
      (100.0 / (1.0 + Math.exp(SLOPE * (t - MIDPOINT)))).round
    end

    def effective(id, z)
      norm = self.for(id)
      raw = z.abs
      return raw if norm.nil?

      spread = [norm["spread"].to_f, MIN_SPREAD].max
      (raw - norm["p50"].to_f) / spread
    end

    def typical?(id, z)
      return z.abs <= 1.5 if self.for(id).nil?

      effective(id, z) <= 1.5
    end

    def classic(z) = (100.0 * Math.exp(-(z.abs ** 2) / 8.0)).round
  end
end
