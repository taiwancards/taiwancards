# frozen_string_literal: true

class PronunciationRecording < ApplicationRecord
  VERDICTS = {unrated: 0, accepted: 1, rejected: 2, unsure: 3}.freeze

  enum(:verdict, VERDICTS, default: :unrated, validate: true)

  belongs_to :user
  belongs_to :lexeme, optional: true

  scope :owned_by, -> (user) { where(user:) }
  scope :rated, -> { where.not(verdict: :unrated) }
  scope :oldest_first, -> { order(:created_at, :id) }

  def rate!(verdict, rejected: [], note: nil)
    update!(
      verdict: verdict,
      rejected_indices: (verdict.to_s == "rejected") ? rejected.map(&:to_i).uniq.sort : [],
      note: note.presence,
      rated_at: Time.current
    )
  end

  def label_for(index)
    return nil if unrated? || unsure?
    return true if accepted?
    return false if rejected_indices.include?(index)
    return false if syllables.length <= 1

    rejected_indices.empty? ? nil : true
  end
end
