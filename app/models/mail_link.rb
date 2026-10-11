# frozen_string_literal: true

class MailLink < ApplicationRecord
  KINDS = %w[open visit unsubscribe].freeze
  LOGIN_DAYS = 30
  TOKEN_BYTES = 32
  TOKEN_LIMIT = 100

  belongs_to :user
  belongs_to :delivery, polymorphic: true, optional: true

  attr_reader :token

  def self.issue(user:, kind:, list:, letter: "", target: "", delivery: nil)
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    link = create!(
      user:,
      kind:,
      list:,
      letter: letter.to_s.first(255),
      target:,
      delivery: delivery&.persisted? ? delivery : nil,
      token_digest: digest(token),
      created_at: Time.current
    )
    link.instance_variable_set(:@token, token)
    link
  end

  def self.find_by_token(token)
    text = token.to_s
    return nil if text.empty? || text.size > TOKEN_LIMIT

    includes(:user).find_by(token_digest: digest(text))
  end

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token)

  def login_open?(now = Time.current) = used_at.nil? && created_at > now - LOGIN_DAYS.days

  def consume!(now = Time.current)
    claimed = self.class.where(id:, used_at: nil).where(created_at: (now - LOGIN_DAYS.days)..).update_all(used_at: now)
    claimed == 1
  end

  def record_click!(source:)
    self.class.where(id:).update_all("clicks_count = clicks_count + 1")
    delivery&.record_click!
    MailEvent.log(user, list:, event: "clicked", letter:, source:, detail: target)
  end
end
