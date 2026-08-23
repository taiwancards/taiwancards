# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class ThresholdsBuilder
      CELLS = %w[overall initial medial final tone].freeze

      CELL_DIMENSION = {"initial" => :initial, "medial" => :medial, "final" => :rime, "tone" => :tone}.freeze

      PER_KEY = 6
      RED_TOUCHES = 0.05

      def initialize(part: "dev", speakers: :fitting, store: TemplateStore.instance, io: $stdout)
        @part = part
        @speakers = speakers
        @store = store
        @io = io
      end

      def call
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        @io&.puts("Thresholds over #{keys.length} syllables of the '#{@part}' split, #{@speakers} voices")
        chunks = FanOut.map(keys, io: @io) { |chunk| tally(chunk) }

        good = merge(chunks.map { |c| c[:good] })
        bad = merge(chunks.map { |c| c[:bad] })

        {
          "generated_at" => Time.current.utc.iso8601,
          "split" => @part,
          "method" => "real recordings of the contrasting syllable, not the target scored against a rival template",
          "thresholds" => CELLS.to_h { |cell| [cell, bounds(good[cell], bad[cell])] }
        }
      end

      def write!(path = nil)
        payload = call
        target = path || File.join(@store.root, "thresholds.json")
        existing = File.exist?(target) ? JSON.parse(File.read(target)) : {}
        merged = existing.merge(payload)
        merged["thresholds"] = (existing["thresholds"] || {}).merge(payload["thresholds"])
        File.write(target, JSON.pretty_generate(merged))
        @io&.puts("Written: #{target}")
        payload
      end

      private

      def tally(keys)
        analyzer = Acoustic::Analyzer.new(@store)
        good = Hash.new { |hash, cell| hash[cell] = Hash.new(0) }
        bad = Hash.new { |hash, cell| hash[cell] = Hash.new(0) }
        available = Tokens.available

        keys.each do |key|
          template = @store.template(key) or next
          norm = template["norm"] || TemplateStore::CITATION

          Tokens.sample(key, PER_KEY, speakers: @speakers).each do |features|
            record(good, analyzer, features, template, norm, nil)
          end

          Acoustic::PartRivals.keys_by_part(key).each do |cell, rival_keys|
            rival_keys.select { |rival| available.include?(rival) }.first(2).each do |rival_key|
              Tokens.sample(rival_key, PER_KEY, speakers: @speakers).each do |features|
                record(bad, analyzer, features, template, norm, cell)
              end
            end
          end
        end

        {good: good, bad: bad}
      end

      def record(histograms, analyzer, features, template, norm, only_cell)
        parts = analyzer.part_scores(analyzer.score_axes(features, template, norm))
        return if parts.empty?

        weights = Acoustic::Weights::BASE.slice(*parts.map { |p| p["id"] })
        histograms["overall"][analyzer.weighted_overall(parts, weights)] += 1

        parts.each do |part|
          next if only_cell && part["id"] != only_cell

          histograms[part["id"]][part["score"]] += 1
        end
      end

      def merge(list)
        list.compact.each_with_object(Hash.new { |hash, cell| hash[cell] = Hash.new(0) }) do |chunk, acc|
          chunk.each { |cell, hist| hist.each { |score, count| acc[cell][score] += count } }
        end
      end

      def bounds(good, bad)
        return {"green" => 87, "red" => 62, "n_self" => 0} if good.blank?

        green = bad.present? ? youden(good, bad) : quantile(good, 0.2)
        red = quantile(good, RED_TOUCHES)

        {
          "green" => green,
          "red" => red,
          "self_median" => quantile(good, 0.5),
          "neg_median" => bad.present? ? quantile(bad, 0.5) : 0,
          "n_self" => good.values.sum,
          "n_neg" => bad.values.sum,
          "green_keeps" => share_at_least(good, green),
          "green_admits" => bad.present? ? share_at_least(bad, green) : 0.0,
          "red_touches" => (100.0 - share_at_least(good, red)).round(1)
        }
      end

      def youden(good, bad)
        (0..100).max_by { |threshold| share_at_least(good, threshold) - share_at_least(bad, threshold) }
      end

      def quantile(hist, q)
        total = hist.values.sum
        return 0 if total.zero?

        target = (total * q).floor
        seen = 0
        hist.keys.sort.each do |score|
          seen += hist[score]
          return score if seen > target
        end

        hist.keys.max
      end

      def share_at_least(hist, score)
        total = hist.values.sum
        return 0.0 if total.zero?

        (100.0 * hist.select { |value, _| value >= score }.values.sum / total).round(1)
      end
    end
  end
end
