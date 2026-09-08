# frozen_string_literal: true

module Pronunciation
  module Corpus
    class SplitAnalysis
      DEFAULT_PART = "dev"

      def initialize(part: self.class::DEFAULT_PART, speakers: :fitting, store: TemplateStore.instance, io: $stdout)
        @part = part
        @speakers = speakers
        @store = store
        @io = io
      end

      private

      def split_keys
        keys = Tokens.keys(@part)
        raise "no keys in the '#{@part}' split" if keys.empty?

        keys
      end
    end
  end
end
