# frozen_string_literal: true

module Huayu
  class SentenceRejectStore < RejectStore
    PATH = AppData.path("huayu/sentence_rejects.jsonl")

    KIND = :sentence
  end
end
