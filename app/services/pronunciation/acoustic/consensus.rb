# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Consensus
      TRUSTED = {"vot_ms" => "vot_reliable", "vot_ratio" => "vot_reliable"}.freeze
      ANY = %w[vot_reliable].freeze

      module_function

      def merge(rows)
        kept = rows.compact
        return kept.first if kept.length < 2

        out = kept.first.dup
        kept.flat_map(&:keys).uniq.each do |field|
          values = pick(kept, field)
          next if values.empty?

          merged = blend(values, field)
          out[field] = merged unless merged.nil?
        end

        out["n_takes"] = kept.length
        out
      end

      def pick(rows, field)
        gate = TRUSTED[field]
        trusted = gate ? rows.select { |row| row[gate] } : rows
        trusted = rows if trusted.empty?
        trusted.filter_map { |row| row[field] }
      end

      def blend(values, field = nil)
        return values.any? if ANY.include?(field)

        head = values.first
        case head
        when Numeric
          DTW::Statistics.median(values.map(&:to_f))
        when true, false
          values.count(true) * 2 >= values.length
        when Array
          columns(values)
        end
      end

      def columns(values)
        length = values.first.length
        return values.first unless values.all? { |v| v.is_a?(Array) && v.length == length }

        values.first.each_index.map { |i| blend(values.map { |v| v[i] }) }
      end
    end
  end
end
