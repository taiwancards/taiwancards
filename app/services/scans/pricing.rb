# frozen_string_literal: true

module Scans
  module Pricing
    PER_MILLION = {
      "claude-fable-5-2" => [8.0, 40.0],
      "claude-opus-5-5" => [4.0, 20.0],
      "claude-opus-5" => [5.0, 25.0],
      "claude-sonnet-5-5" => [2.0, 10.0],
      "claude-sonnet-5" => [2.0, 10.0],
      "claude-haiku-5-5" => [0.10, 0.50]
    }.freeze

    module_function

    def known?(model) = PER_MILLION.key?(model.to_s)

    def cost(model, input_tokens, output_tokens)
      input, output = PER_MILLION[model.to_s]
      return if input.nil?

      (input_tokens.to_i * input + output_tokens.to_i * output) / 1_000_000.0
    end
  end
end
