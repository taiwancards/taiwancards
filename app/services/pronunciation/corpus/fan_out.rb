# frozen_string_literal: true

require "etc"

module Pronunciation
  module Corpus
    module FanOut
      module_function

      def workers
        levels = 0.upto(3).map { |level| `sysctl -n hw.perflevel#{level}.logicalcpu 2>/dev/null`.to_i }
        best = levels.max.to_i
        best.positive? ? best : [Etc.nprocessors - 2, 1].max
      end

      def map(items, workers: self.workers(), io: nil, &block)
        size = [(items.length / [workers, 1].max.to_f).ceil, 1].max
        chunks = items.each_slice(size).to_a
        return [block.call(items)] if chunks.length <= 1

        io&.puts("  computing on #{chunks.length} cores…")
        collect(chunks, &block)
      end

      def plain(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, nested), acc| acc[key] = plain(nested) }
        when Array
          value.map { |nested| plain(nested) }
        else
          value
        end
      end

      def collect(chunks, &block)
        pipes = chunks.map { IO.pipe }

        pids = chunks.each_with_index.map do |chunk, index|
          fork do
            pipes.each_with_index do |(reader, writer), other|
              reader.close
              writer.close unless other == index
            end

            Marshal.dump(plain(block.call(chunk)), pipes[index][1])
            pipes[index][1].close
            exit!(0)
          end
        end

        results = pipes.map do |reader, writer|
          writer.close
          raw = reader.read
          reader.close
          raw.to_s.empty? ? nil : Marshal.load(raw)
        end

        pids.each { |pid| Process.waitpid(pid) }
        results.compact
      end
    end
  end
end
