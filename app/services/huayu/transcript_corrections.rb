# frozen_string_literal: true

module Huayu
  module TranscriptCorrections
    DATA = JsonData.new("huayu/transcript_corrections.json", default: {})

    module_function

    def all = DATA.value

    def apply(text) = all.fetch(text, text)

    def reset! = DATA.reset!
  end
end
