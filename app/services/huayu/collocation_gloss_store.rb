# frozen_string_literal: true

module Huayu
  class CollocationGlossStore < JsonlStore
    PATH = AppData.path("huayu/collocation_glosses.jsonl")

    Entry = Data.define(:text, :en, :ru)
  end
end
