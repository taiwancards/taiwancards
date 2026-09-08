# frozen_string_literal: true

module Huayu
  class SenseGlossStore < JsonlStore
    PATH = AppData.path("huayu/sense_glosses.jsonl")

    Entry = Data.define(:word, :zh, :en, :ru)

    def self.key(entry) = [entry.word, entry.zh]
  end
end
