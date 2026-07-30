# frozen_string_literal: true

module Huayu
  class SegmentationVocabulary
    PATH = AppData.path("huayu/segmentation_vocab.json")

    class << self
      def words
        @words ||= load
      end

      def reset!
        @words = nil
      end

      private

      def load
        return Set.new unless File.exist?(PATH)

        payload = JSON.parse(File.read(PATH))
        Array(payload["words"]).select { |text| text.to_s.length >= 2 }.to_set
      end
    end
  end
end
