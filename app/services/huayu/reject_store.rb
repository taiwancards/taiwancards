# frozen_string_literal: true

module Huayu
  class RejectStore < JsonlStore
    REASONS = %w[fragment ambiguous garbled off_corpus].freeze

    Entry = Data.define(:text, :reason, :note, :en, :ru) do
      def initialize(text:, reason:, note: nil, en: nil, ru: nil)
        super
      end
    end

    class << self
      def texts = read.map(&:text).to_set

      private

      def serialize(entry) = JSON.generate(entry.to_h.compact)
    end
  end
end
