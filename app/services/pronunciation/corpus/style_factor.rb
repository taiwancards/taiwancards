# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class StyleFactor
      PATH = "style_factor.json"
      MIN_PER_KEY = 4
      MIN_KEYS = 20

      def initialize(store: TemplateStore.instance, io: $stdout)
        @store = store
        @io = io
      end

      def factors
        @factors ||= read || build
      end

      def correct(model)
        return model if factors.empty?

        median = factors["median"] || 1.0
        per_field = factors["per_field"] || {}
        corrected = model.dup

        corrected.each_key do |field|
          value = corrected[field]
          corrected[field] = value / (per_field[field] || median) if value.is_a?(Numeric)
        end

        if corrected["tone_contour"].is_a?(Array)
          divisor = per_field["tone_range"] || median
          corrected["tone_contour"] = corrected["tone_contour"].map { |x| x / divisor }
        end

        corrected
      end

      def build
        buckets = collect
        per_field = {}

        Acoustic::Variability::FIELDS.each_key do |field|
          citation = []
          connected = []
          buckets.each_value do |group|
            near = group[:citation].filter_map { |row| row[field] }
            far = group[:connected].filter_map { |row| row[field] }
            next if near.length < MIN_PER_KEY || far.length < MIN_PER_KEY

            citation << Acoustic::Dtw.mad(near)
            connected << Acoustic::Dtw.mad(far)
          end

          next if citation.length < MIN_KEYS

          middle = Acoustic::Dsp.median(citation)
          next unless middle.positive?

          per_field[field] = Acoustic::Dsp.median(connected) / middle
        end

        @factors = {"per_field" => per_field, "median" => Acoustic::Dsp.median(per_field.values)}
      end

      def write!
        build
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(@factors))
        @io&.puts(
          "median factor #{@factors["median"].round(2)} over #{@factors["per_field"].length} features"
        )
        @factors
      end

      private

      def read
        path = File.join(@store.root, PATH)
        File.exist?(path) ? JSON.parse(File.read(path)) : nil
      end

      def collect
        buckets = Hash.new { |hash, key| hash[key] = {citation: [], connected: []} }

        Tokens.available.each do |key|
          Tokens.each(key) do |row|
            next unless row["_source"].to_s.start_with?("moe")

            bucket = row["_n_syllables"] == 1 ? :citation : :connected
            buckets[key][bucket] << row
          end
        end

        buckets
      end
    end
  end
end
