# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class AxisNormsBuilder
      STEP = 0.01
      CAP = 40.0

      QUANTILES = {"p10" => 0.10, "p25" => 0.25, "p50" => 0.50, "p75" => 0.75, "p90" => 0.90, "p99" => 0.99}.freeze

      SEPARATION_K = 2.9
      FALLBACK_SEPARATION = 1.0
      MIN_GAP = 0.2

      AXIS_PART = {
        "tone" => "tone",
        "initial" => "initial",
        "sibilant" => "initial",
        "medial" => "medial",
        "vowel" => "final",
        "coda" => "final"
      }.freeze

      PARTS = %w[initial medial final tone].freeze

      def initialize(part: "dev", store: TemplateStore.instance, io: $stdout)
        @part = part
        @store = store
        @io = io
      end

      def call
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        @io&.puts("Axis scales over #{keys.length} syllables of the '#{@part}' split")
        chunks = FanOut.map(keys, io: @io) { |chunk| tally(chunk) }

        positive = merge(chunks.map { |c| c[:positive] })
        negative = merge(chunks.map { |c| c[:negative] })
        axes = positive.keys.sort.to_h { |id| [id, scale(positive[id], negative[id])] }

        {
          "generated_at" => Time.current.utc.iso8601,
          "split" => @part,
          "n_keys" => keys.length,
          "axes" => axes,
          "contrast_check" => PARTS.to_h { |part| [part, compare_sources(part, axes)] }.compact
        }
      end

      def write!(path = nil)
        payload = call
        target = path || File.join(@store.root, AxisNorms::PATH)
        File.write(target, JSON.pretty_generate(payload))
        @io&.puts("Written: #{target}")
        payload
      end

      private

      def tally(keys)
        analyzer = Acoustic::Analyzer.new(@store)
        contrasts = Acoustic::PartContrasts.new(@store)
        positive = Hash.new { |hash, id| hash[id] = Hash.new(0) }
        negative = Hash.new { |hash, id| hash[id] = Hash.new(0) }

        keys.each do |key|
          template = @store.template(key) or next
          norm = template["norm"] || TemplateStore::CITATION
          rivals = Rivals.for(key, store: @store, norm: norm)
          profiles = contrasts.profiles(key, norm)

          Tokens.each(key) do |features|
            analyzer.score_axes(features, template, norm).each { |axis| add(positive, axis["id"], axis["z"]) }

            profiles.each do |part, profile|
              distance = Acoustic::Contrasts.weighted_distance(features, template, profile)
              add(positive, "contrast_#{part}", distance) if distance
            end

            rivals.each do |dimension, list|
              part = Rivals::PART_OF_DIMENSION[dimension]
              profile = profiles[part]

              list.each do |rival|
                analyzer.score_axes(features, rival, norm).each do |axis|
                  add(negative, axis["id"], axis["z"]) if AXIS_PART[axis["id"]] == part
                end

                next if profile.blank?

                distance = Acoustic::Contrasts.weighted_distance(features, rival, profile)
                add(negative, "contrast_#{part}", distance) if distance
              end
            end
          end
        end

        {positive: positive, negative: negative}
      end

      def add(histograms, id, value)
        histograms[id][(value.to_f.abs.clamp(0.0, CAP) / STEP).round] += 1
      end

      def merge(list)
        list.compact.each_with_object(Hash.new { |hash, id| hash[id] = Hash.new(0) }) do |chunk, acc|
          chunk.each { |id, hist| hist.each { |bucket, count| acc[id][bucket] += count } }
        end
      end

      def scale(positive, negative)
        own = summarize(positive)
        rival = negative.present? ? summarize(negative) : nil
        center = own["p50"].to_f
        gap = rival ? rival["p50"].to_f - center : 0.0
        separated = gap > MIN_GAP
        spread = separated ? gap / SEPARATION_K : [own["p90"].to_f - center, FALLBACK_SEPARATION].max

        own.merge(
          "spread" => spread.round(3),
          "rival_p50" => rival&.fetch("p50", nil),
          "n_rival" => rival ? rival["n"] : 0,
          "separated" => separated,
          "auc" => rival ? auc(positive, negative).round(4) : nil
        )
      end

      def compare_sources(part, axes)
        contrast = axes["contrast_#{part}"]
        return nil if contrast.nil? || contrast["auc"].nil?

        own = axes.values_at(*AXIS_PART.select { |_, mapped| mapped == part }.keys).compact
        best = own.filter_map { |axis| axis["auc"] }.max

        {
          "wins" => (best.nil? || contrast["auc"] > best) ? "contrast" : "axis",
          "contrast_auc" => contrast["auc"],
          "axis_auc" => best
        }
      end

      def auc(positive, negative)
        buckets = (positive.keys | negative.keys).sort
        pos_total = positive.values.sum.to_f
        neg_total = negative.values.sum.to_f
        return 0.5 if pos_total.zero? || neg_total.zero?

        seen = 0.0
        wins = 0.0
        buckets.each do |bucket|
          mine = positive[bucket].to_i
          theirs = negative[bucket].to_i
          wins += mine * (seen + (theirs / 2.0))
          seen += theirs
        end

        1.0 - (wins / (pos_total * neg_total))
      end

      def summarize(hist)
        total = hist.values.sum
        return {"n" => 0} if total.zero?

        wanted = QUANTILES.transform_values { |q| (total * q).floor }
        seen = 0
        found = {}

        hist.keys.sort.each do |bucket|
          seen += hist[bucket]
          wanted.each { |name, at| found[name] ||= (bucket * STEP).round(3) if seen > at }
          break if found.length == wanted.length
        end

        last = (hist.keys.max * STEP).round(3)
        QUANTILES.keys.to_h { |name| [name, found[name] || last] }.merge("n" => total)
      end
    end
  end
end
