# frozen_string_literal: true

class ContentSource < ApplicationRecord
  has_many :lexemes, dependent: :nullify
  has_many :reading_texts, dependent: :nullify

  enum(
    :register,
    {colloquial: 0, literary: 1, publicistic: 2, official: 3, academic: 4, internet: 5, subtitles: 6},
    prefix: true
  )

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  validates :attribution, presence: true, if: :carries_content?

  after_save :forget_visibility_cache
  after_destroy :forget_visibility_cache

  scope :ordered, -> { order(:register, :name) }
  scope :enabled_for_everyone, -> { where(enabled: true) }

  scope :countable, -> { where.not(register: nil) }

  scope :publishable, -> { where(license_commercial: true, statistics_only: false) }
  scope :measurement_only, -> { where("NOT license_commercial OR statistics_only") }

  def self.visible_to(user)
    scope = publishable
    user&.admin? ? scope.where("enabled OR enabled_for_admins") : scope.enabled_for_everyone
  end

  def self.visible_ids_for(user)
    visible_to(user).pluck(:id)
  end

  def visible_to?(user)
    return false unless publishable?

    enabled? || (enabled_for_admins? && user&.admin?)
  end

  def hidden_from_everyone?
    !enabled? || !publishable?
  end

  def publishable?
    license_commercial? && !statistics_only?
  end

  def measurement_only?
    !publishable?
  end

  def carries_content?
    publishable? && (enabled? || enabled_for_admins?)
  end

  def total_items
    sentences_count + collocations_count + audio_count + translations_count
  end

  private

  def forget_visibility_cache
    Current.visible_source_ids = nil
  end
end
