# frozen_string_literal: true

class User < ApplicationRecord
  include Preferenced

  has_secure_password

  encrypts :google_refresh_token
  encrypts :google_access_token

  has_many :activity_events, dependent: :destroy
  has_many :pronunciation_attempts, dependent: :destroy
  has_many :syllable_skills, dependent: :delete_all
  has_many :lexeme_reviews, dependent: :destroy
  has_many :lexeme_memories, dependent: :destroy
  has_many :reading_texts, dependent: :destroy
  has_many :collections, dependent: :destroy
  has_many :collection_groups, dependent: :delete_all
  has_many :deck_shares, dependent: :delete_all
  has_many :placement_tests, dependent: :destroy
  has_many :study_plans, dependent: :destroy
  has_one :voice_profile, dependent: :destroy

  normalizes :email, with: -> (email) { email.to_s.strip.downcase }
  normalizes :google_email, with: -> (email) { email.to_s.strip.downcase.presence }

  before_save :settle_admin

  validates :email, presence: true, uniqueness: {case_sensitive: false}, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :password, length: {minimum: 8}, allow_nil: true
  validates :locale, inclusion: {in: -> (_) { I18n.available_locales.map(&:to_s) }}

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  def self.for_google(auth, locale: nil)
    user = find_by(google_uid: auth.uid)
    user ||= find_by(google_email: auth.info.email.to_s.downcase)
    user ||= find_by(email: auth.info.email.to_s.downcase)
    user ||= new(
      email: auth.info.email,
      name: auth.info.name,
      password: SecureRandom.base58(24),
      locale: locale.presence || I18n.default_locale.to_s
    )
    user.assign_google(auth)
    user.email_verified_at ||= Time.current
    user.save!
    user
  end

  def assign_google(auth)
    self.google_uid = auth.uid
    self.google_email = auth.info.email
    credentials = auth.credentials
    self.google_refresh_token = credentials.refresh_token if credentials.refresh_token.present?
    self.google_access_token = credentials.token
    self.google_token_expires_at = credentials.expires_at ? Time.at(credentials.expires_at) : nil
  end

  def link_google!(auth)
    assign_google(auth)
    save!
  end

  def google_linked?
    google_uid.present?
  end

  def verified?
    email_verified_at.present?
  end

  def display_name
    name.presence || email
  end

  ADMIN_GOOGLE_EMAIL = ENV.fetch("ADMIN_GOOGLE_EMAIL", "taiwancards@pm.me").downcase.freeze

  def admin?
    google_email.present? && google_email == ADMIN_GOOGLE_EMAIL
  end

  def restricted_access?
    restricted_content?
  end

  SEEN_THROTTLE = 15.minutes
  VISIT_GAP = 30.minutes

  def seen!(now = Time.current)
    return if last_seen_at && now - last_seen_at < SEEN_THROTTLE

    visit = last_seen_at.nil? || now - last_seen_at > VISIT_GAP ? 1 : 0
    self.class.where(id: id).update_all(["last_seen_at = ?, visits_count = visits_count + ?", now, visit])
  rescue => e
    Rails.logger.warn("presence tracking failed: #{e.class}: #{e.message}")
  end

  MAX_MOBILE_TABS = 4
  ZHUYIN_POSITIONS = %w[right over].freeze
  TEXT_DIRECTIONS = %w[horizontal vertical].freeze

  preference :zhuyin_position, one_of: ZHUYIN_POSITIONS
  preference :text_direction, one_of: TEXT_DIRECTIONS

  def mobile_tabs
    Array(prefs["mobile_tabs"]).map(&:to_s)
  end

  def mobile_tabs=(value)
    write_prefs("mobile_tabs" => Array(value).compact_blank.map(&:to_s).first(MAX_MOBILE_TABS))
  end

  def vertical_text?
    text_direction == "vertical"
  end

  MAX_MISSES = 99

  def intro_seen_version
    prefs["intro_version"].to_i
  end

  def intro_done?
    prefs["intro_stage"].to_s == "done"
  end

  def intro_running?
    prefs["intro_stage"].to_s == "running"
  end

  def intro_step
    prefs["intro_step"].presence
  end

  def intro_chapters
    Array(prefs["intro_chapters"]).map(&:to_s)
  end

  def intro
    @intro ||= Intro::Progress.new(self)
  end

  def phonetic_misses
    Hash(prefs["phonetic_misses"]).transform_values(&:to_i)
  end

  def record_phonetic_misses!(counts)
    fresh = Hash(counts).transform_keys(&:to_s).transform_values { |value| value.to_i.clamp(0, MAX_MISSES) }
    merged = phonetic_misses.merge(fresh) { |_key, old, new| (old + new).clamp(0, MAX_MISSES) }
    update!(prefs: prefs.merge("phonetic_misses" => merged.reject { |_key, value| value.zero? }))
  end

  KEPT_ON_RESET = %w[
    locale
    zhuyin_position
    text_direction
    mobile_tabs
  ].freeze

  LEVELS = %w[zero phonetics 1 2 3 4 5 6 7].freeze
  START_LEVELS = %w[zero phonetics characters experienced].freeze
  MAX_PATH_STEPS = 20
  MAX_PRACTICE_RUNS = 9999

  preference :start_level, one_of: START_LEVELS, allow_nil: true

  def level
    stored = prefs["level"].to_s
    return stored if LEVELS.include?(stored)

    start_level == "phonetics" ? "phonetics" : LEVELS.first
  end

  def level=(value)
    write_prefs("level" => value.to_s.presence_in(LEVELS) || LEVELS.first)
  end

  def level_grade
    Integer(level, exception: false) || 0
  end

  def knows_phonetics?
    level != "zero"
  end

  def start_chosen?
    start_level.present?
  end

  def path_steps_done
    Array(prefs["path_steps"]).map(&:to_s)
  end

  def mark_path_step!(key)
    update!(prefs: prefs.merge("path_steps" => (path_steps_done | [key.to_s]).first(MAX_PATH_STEPS)))
  end

  def unmark_path_step!(key)
    update!(prefs: prefs.merge("path_steps" => path_steps_done - [key.to_s]))
  end

  def zhuyin_mastery
    Hash(prefs["zhuyin_mastery"])
  end

  def update_zhuyin_mastery!(mastery)
    update!(prefs: prefs.merge("zhuyin_mastery" => mastery))
  end

  def practice_runs
    Hash(prefs["practice_runs"]).transform_values(&:to_i)
  end

  def record_practice_run!(kind)
    key = kind.to_s
    merged = practice_runs.merge(key => (practice_runs[key].to_i + 1).clamp(0, MAX_PRACTICE_RUNS))
    update!(prefs: prefs.merge("practice_runs" => merged))
  end

  private

  def settle_admin
    self.admin = admin?
  end
end
