# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class SyllableQuality
      PATH = "syllable_quality.json"
      MIN_TOKENS = 3
      MIN_TRAIN = 3
      PROBES = 8

      def initialize(part: "all", store: TemplateStore.instance, io: $stdout)
        @part = part
        @store = store
        @io = io
      end

      def call
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        @io&.puts("Quality of #{keys.length} syllables")
        FanOut.map(keys, io: @io) { |chunk| measure(chunk) }.flatten(1).compact.sort_by { |row| -row["self"] }
      end

      def write!
        rows = call
        File.write(File.join(@store.root, PATH), JSON.pretty_generate(rows))
        rows
      end

      private

      def measure(keys)
        analyzer = Acoustic::Analyzer.new(@store)
        keys.filter_map { |key| row(analyzer, key) }
      end

      def row(analyzer, key)
        rows = citations(key)
        return nil if rows.length < MIN_TOKENS
        return nil if @store.template(key).nil?

        selves = []
        margins = []
        wins = 0
        seen = 0

        rows.first(PROBES).each do |features|
          train = rows.reject { |other| other["_file"] == features["_file"] }
          next if train.length < MIN_TRAIN

          template = held_out(key, train)
          next if template.nil?

          score = overall(analyzer, features, template)
          next if score.nil?

          seen += 1
          selves << score
          wins += 1 if best_rival(analyzer, features, key, score, margins)
        end

        return nil if seen < MIN_TOKENS

        {
          "key" => key,
          "n" => seen,
          "self" => median(selves).round,
          "top1" => (100.0 * wins / seen).round(1),
          "margin" => median(margins).round
        }
      end

      def best_rival(analyzer, features, key, score, margins)
        best = nil
        rivals(key).each do |rival|
          other = overall(analyzer, features, rival)
          next if other.nil?

          best = other if best.nil? || other > best
        end

        return true if best.nil?

        margins << (score - best)
        score > best
      end

      def rivals(key)
        @rivals ||= {}
        @rivals[key] ||= begin
          syllable, tone = Acoustic::Syllables.parse_key(key)
          Acoustic::Syllables.confusion_set(syllable, tone).filter_map { |other| @store.template(other) }
        end
      end

      def citations(key)
        rows = []
        Tokens.each(key) { |row| rows << row if row["_n_syllables"] == 1 }
        rows
      end

      def held_out(key, train)
        meta = train.map { |r| {"speaker" => r["_speaker"], "source" => r["_source"], "n_syllables" => 1} }
        Acoustic::Templates.build(
          key,
          train,
          meta,
          variability: variability,
          vot: VotNorms.for_rows(key, train)
        )
      rescue StandardError
        nil
      end

      def variability
        return @variability if defined?(@variability)

        path = File.join(@store.root, "variability.json")
        @variability = File.exist?(path) ? JSON.parse(File.read(path))["model"] : nil
      end

      def overall(analyzer, features, template)
        return nil if template.nil?

        norm = template["norm"] || TemplateStore::CITATION
        parts = analyzer.part_scores(analyzer.score_axes(features, template, norm))
        return nil if parts.empty?

        analyzer.weighted_overall(parts, Acoustic::Weights::BASE.slice(*parts.map { |p| p["id"] }))
      end

      def median(values)
        return 0 if values.empty?

        values.sort[values.length / 2]
      end
    end
  end
end
