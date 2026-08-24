# frozen_string_literal: true

module Huayu
  class SegmentationVocabulary
    PATH = AppData.path("huayu/segmentation_vocab.json")
    NAMES_PATH = AppData.path("huayu/segmentation_names.json")
    NAME_PRIOR = 0.00015

    class << self
      def words
        @words ||= load(PATH) | names
      end

      def names
        @names ||= load(NAMES_PATH)
      end

      def name_prior
        @name_prior ||= payload(NAMES_PATH)["prior"]&.to_f || NAME_PRIOR
      end

      def reset!
        @words = nil
        @names = nil
        @name_prior = nil
      end

      private

      def load(path)
        Array(payload(path)["words"]).select { |text| text.to_s.length >= 2 }.to_set
      end

      def payload(path)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end
    end
  end
end
