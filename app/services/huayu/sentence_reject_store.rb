# frozen_string_literal: true

module Huayu
  class SentenceRejectStore < RejectStore
    PATH = AppData.path("huayu/sentence_rejects.jsonl")

    KIND = :sentence
    UNCONDITIONAL = %w[garbled pun crude false].freeze

    def self.unconditional?(reason) = UNCONDITIONAL.include?(reason.to_s)
  end
end
