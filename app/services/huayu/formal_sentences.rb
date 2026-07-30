# frozen_string_literal: true

module Huayu
  class FormalSentences
    REGISTERS = %w[official publicistic academic literary].freeze

    def self.ids(registers: REGISTERS)
      sources = ContentSource.where(register: registers).select(:id)
      Lexeme
        .where(kind: :sentence)
        .joins(:lexeme_content_sources)
        .where(lexeme_content_sources: {content_source_id: sources})
        .distinct
        .pluck(:id)
        .to_set
    end
  end
end
