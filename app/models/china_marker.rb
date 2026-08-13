# frozen_string_literal: true

class ChinaMarker < ApplicationRecord
  enum(:band, {hard: 0, soft: 1}, prefix: true)

  validates :word, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :hard, -> { active.where(band: :hard) }
  scope :soft, -> { active.where(band: :soft) }

  def self.words
    @words ||= hard.pluck(:word)
  end

  def self.reset_cache!
    @words = nil
    Huayu::ChinaGuard.reset!
  end

  def self.detect(text)
    words.select { |word| text.include?(word) }
  end

  def self.rejects?(text)
    words.any? { |word| text.include?(word) }
  end
end
