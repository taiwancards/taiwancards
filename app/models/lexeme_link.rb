# frozen_string_literal: true

class LexemeLink < ApplicationRecord
  belongs_to :parent, class_name: "Lexeme"
  belongs_to :child, class_name: "Lexeme"

  validates :child_id, uniqueness: {scope: %i[parent_id position]}
end
