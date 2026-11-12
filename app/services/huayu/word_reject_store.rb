# frozen_string_literal: true

module Huayu
  class WordRejectStore < RejectStore
    PATH = AppData.path("huayu/word_rejects.jsonl")

    KIND = :word
  end
end
