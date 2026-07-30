# frozen_string_literal: true

class MainlandMarker < ApplicationRecord
  validates :word, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def self.words
    @words ||= active.pluck(:word)
  end

  def self.reset_cache!
    @words = nil
  end

  def self.detect(text)
    words.select { |word| text.include?(word) }
  end

  def self.rejects?(text)
    words.any? { |word| text.include?(word) }
  end
end
