# frozen_string_literal: true

module Huayu
  class CollocationRejectStore < RejectStore
    PATH = AppData.path("huayu/collocation_rejects.jsonl")

    KIND = :collocation
  end
end
