# frozen_string_literal: true

class DeckShare < ApplicationRecord
  TOKEN_BYTES = 12
  DEFAULT_TTL = 90.days
  MAX_ACTIVE_PER_USER = 50

  belongs_to :user

  enum :kind, {deck: 0, group: 1}, prefix: true

  validates :name, presence: true, length: {maximum: 200}
  validates :token, presence: true, uniqueness: true

  before_validation :assign_token, on: :create
  before_validation :assign_expiry, on: :create

  scope :live, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  def self.find_live(token)
    live.find_by(token: token.to_s)
  end

  def to_param = token

  def revoked? = revoked_at.present?

  def expired? = expires_at.present? && expires_at.past?

  def live? = !revoked? && !expired?

  def revoke!
    update_column(:revoked_at, Time.current)
  end

  def record_acceptance!
    self.class.where(id:).update_all("accepted_count = accepted_count + 1")
  end

  def decks
    Array(payload["decks"])
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(TOKEN_BYTES)
  end

  def assign_expiry
    self.expires_at ||= DEFAULT_TTL.from_now
  end
end
