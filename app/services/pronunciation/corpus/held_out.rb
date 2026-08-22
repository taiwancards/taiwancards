# frozen_string_literal: true

require "json"

module Pronunciation
  module Corpus
    class HeldOut
      MIN_TRAIN = 3

      def initialize(store: TemplateStore.instance)
        @store = store
      end

      def citations(key)
        rows = []
        Tokens.each(key) { |row| rows << row if row["_n_syllables"] == 1 }
        rows
      end

      def template(key, train)
        return nil if train.length < MIN_TRAIN

        meta = train.map { |row| {"speaker" => row["_speaker"], "source" => row["_source"], "n_syllables" => 1} }
        Acoustic::Templates.build(key, train, meta, variability: variability, vot: VotNorms.for_rows(key, train))
      rescue StandardError
        nil
      end

      def without(rows, features) = rows.reject { |other| other["_file"] == features["_file"] }

      def overall(analyzer, features, template)
        return nil if template.nil?

        norm = template["norm"] || TemplateStore::CITATION
        parts = analyzer.part_scores(analyzer.score_axes(features, template, norm))
        return nil if parts.empty?

        analyzer.weighted_overall(parts, Acoustic::Weights::BASE.slice(*parts.map { |part| part["id"] }))
      end

      private

      def variability
        return @variability if defined?(@variability)

        path = File.join(@store.root, "variability.json")
        @variability = File.exist?(path) ? JSON.parse(File.read(path))["model"] : nil
      end
    end
  end
end
