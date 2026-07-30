# frozen_string_literal: true

class SentenceWord < ApplicationRecord
  belongs_to :sentence, class_name: "Lexeme"
  belongs_to :lexeme

  scope :ranked, -> { order(gdex: :desc, sentence_id: :asc) }
  scope :for_word, -> (lexeme) { where(lexeme: lexeme).ranked }
end
