# frozen_string_literal: true

module Content
  class Preload
    CACHES = [
      -> { Huayu::WordFrequency.instance },
      -> { Huayu::BigramFrequency.instance },
      -> { Huayu::SegmentationVocabulary.words },
      -> { Huayu::TextAnalyzer.vocabulary },
      -> { Huayu::StrokeData.has?("一") },
      -> { Huayu::CharacterTiers.instance }
    ].freeze

    Result = Data.define(:warmed, :failed) do
      def to_s = "preload: #{warmed} caches warmed#{failed.zero? ? "" : ", #{failed} unavailable"}"
    end

    def call
      warmed = 0
      failed = 0

      CACHES.each do |cache|
        cache.call
        warmed += 1
      rescue StandardError
        failed += 1
      end

      Result.new(warmed:, failed:)
    end
  end
end
