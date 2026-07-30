# frozen_string_literal: true

module Textbook
  module Devalue
    module_function

    def parse(payload)
      payload["nodes"]
        .compact
        .select { |node| node["type"] == "data" }
        .map { |node| unflatten(node["data"]) }
    end

    def unflatten(values, index = 0, cache = {})
      return nil if index.negative?
      return cache[index] if cache.key?(index)

      value = values[index]
      case value
      when Array
        arr = []
        cache[index] = arr
        value.each { |v| arr << unflatten(values, v, cache) }
        arr
      when Hash
        obj = {}
        cache[index] = obj
        value.each { |k, v| obj[k] = unflatten(values, v, cache) }
        obj
      else
        cache[index] = value
      end
    end
  end
end
