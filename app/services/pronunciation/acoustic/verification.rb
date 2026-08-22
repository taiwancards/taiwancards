# frozen_string_literal: true

module Pronunciation
  module Acoustic
    module Verification
      POOL_SIZE = 96
      DOUBTFUL_PERCENTILE = 0.52
      MISMATCH_PERCENTILE = 0.68
      MIN_SYLLABLES = 2
      SETTLED_SCORE = 72

      module_function

      # A reading that already matches its own templates well cannot be a reading
      # of something else, so the field is only consulted when the score is low.
      def check(rows, overall: nil, store: TemplateStore.instance, analyzer: nil)
        wanted = rows.reject { |row| row[:absent] }
        return nil if wanted.length < MIN_SYLLABLES
        return settled(wanted.length) if overall && overall >= SETTLED_SCORE

        judge = analyzer || Analyzer.new(store)
        rivals = pool(store)
        return nil if rivals.length < POOL_SIZE / 2

        scored = wanted.filter_map { |row| place(judge, store, rivals, row) }
        return nil if scored.empty?

        share = scored.sum { |row| row["percentile"] } / scored.length

        {
          "confidence" => (1.0 - share).round(3),
          "code" => code_for(share),
          "n" => scored.length,
          "syllables" => scored
        }
      end

      def settled(count)
        {"confidence" => 1.0, "code" => "read.ok", "n" => count, "syllables" => []}
      end

      def code_for(share)
        return "read.mismatch" if share >= MISMATCH_PERCENTILE
        return "read.doubtful" if share >= DOUBTFUL_PERCENTILE

        "read.ok"
      end

      # How the expected syllable places against a fixed spread of the inventory:
      # a reading of some other text leaves it in the middle of the field.
      def place(analyzer, store, rivals, row)
        own = overall(analyzer, row[:features], row[:template], row[:norm])
        return nil if own.nil?

        beaten = 0
        counted = 0
        rivals.each do |key|
          next if key == row[:key]

          template = store.template(key, row[:norm]) || store.template(key)
          next if template.nil?

          score = overall(analyzer, row[:features], template, row[:norm])
          next if score.nil?

          counted += 1
          beaten += 1 if score > own
        end

        return nil if counted.zero?

        {
          "index" => row[:index],
          "key" => row[:key],
          "score" => own,
          "percentile" => (beaten.to_f / counted).round(3)
        }
      end

      def overall(analyzer, features, template, norm)
        axes = analyzer.score_axes(features, template, norm)
        axes.empty? ? nil : analyzer.overall_score(axes)
      rescue StandardError
        nil
      end

      def pool(store)
        @pool ||= {}
        @pool[store.root] ||= build_pool(store)
      end

      def reset! = @pool = {}

      # An even spread over the inventory, taken the same way every time so a
      # reading is judged against the same field on every attempt.
      def build_pool(store)
        keys = store.index&.fetch("keys", nil)
        keys = keys.is_a?(Hash) ? keys.keys : Array(keys)
        return [] if keys.length < POOL_SIZE

        sorted = keys.sort
        step = sorted.length.to_f / POOL_SIZE
        Array.new(POOL_SIZE) { |i| sorted[(i * step).floor] }.uniq
      rescue StandardError
        []
      end
    end
  end
end
