# frozen_string_literal: true

module Content
  class Preload
    CACHES = {
      "word_frequency" => -> { Huayu::WordFrequency.instance },
      "bigram_frequency" => -> { Huayu::BigramFrequency.instance },
      "segmentation_vocabulary" => -> { Huayu::SegmentationVocabulary.words },
      "text_analyzer_vocabulary" => -> { Huayu::TextAnalyzer.vocabulary },
      "stroke_data" => -> { Huayu::StrokeData.has?("一") },
      "character_tiers" => -> { Huayu::CharacterTiers.instance }
    }.freeze

    Result = Data.define(:warmed, :failed) do
      def to_s = "preload: #{warmed} caches warmed#{failed.zero? ? "" : ", #{failed} unavailable"}"
    end

    def call
      warmed = 0
      failed = 0

      CACHES.each do |name, cache|
        cache.call
        warmed += 1
      rescue StandardError => e
        failed += 1
        Rails.logger.error("preload: #{name} unavailable: #{e.class}: #{e.message}")
      end

      Result.new(warmed:, failed:)
    end
  end
end
