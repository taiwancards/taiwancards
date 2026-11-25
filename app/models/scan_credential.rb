# frozen_string_literal: true

class ScanCredential < ApplicationRecord
  ID = 1
  STATES = %w[unchecked ok rejected].freeze
  STATUSES = (%w[missing] + STATES).freeze
  ENVIRONMENT = "ANTHROPIC_API_KEY"

  encrypts :secret

  validates :state, inclusion: {in: STATES}

  def self.current = find_by(id: ID) || new(id: ID)

  def self.row! = create_or_find_by!(id: ID)

  def self.encryption_ready?
    config = ActiveRecord::Encryption.config
    [config.primary_key, config.key_derivation_salt].all?(&:present?)
  end

  def self.environment_key = ENV[ENVIRONMENT].presence&.then { |secret| Scans::ApiKey.new(secret, "environment") }

  def stored_key
    return @stored_key if defined?(@stored_key)

    @stored_key = readable_secret&.then { |text| Scans::ApiKey.new(text, "stored") }
  end

  def api_key = stored_key || self.class.environment_key

  def status
    key = api_key
    return "missing" if key.nil?
    return "unchecked" unless checked_digest == key.digest

    state
  end

  def usable? = %w[unchecked ok].include?(status)

  def chosen_model = model.presence_in(Scans::Pricing::PER_MILLION.keys)

  def last_check_at = (checked_at if api_key && checked_digest == api_key.digest)

  def check_due?(now = Time.current) = api_key.present? &&
    (status != "ok" || last_check_at.nil? || last_check_at < now - 1.hour)

  def days_left(today = Time.zone.today) = expires_on && (expires_on - today).to_i

  def unreadable? = secret_before_type_cast.present? && readable_secret.nil?

  def reload(...)
    remove_instance_variable(:@stored_key) if defined?(@stored_key)
    super
  end

  private

  def readable_secret
    secret.presence
  rescue ActiveRecord::Encryption::Errors::Base
    nil
  end
end
