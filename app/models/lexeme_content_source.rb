# frozen_string_literal: true

class LexemeContentSource < ApplicationRecord
  belongs_to :lexeme
  belongs_to :content_source

  validates :content_source_id, uniqueness: {scope: :lexeme_id}
end
