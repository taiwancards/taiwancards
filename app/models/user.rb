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
  has_many :placement_tests, dependent: :destroy
  has_many :study_plans, dependent: :destroy
  has_one :voice_profile, dependent: :destroy

  normalizes :email, with: -> (email) { email.to_s.strip.downcase }
  normalizes :google_email, with: -> (email) { email.to_s.strip.downcase.presence }

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

  def restricted_access?
    restricted_content?
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

  def character_tier
    stored = prefs["character_tier"].to_i
    stored.clamp(Huayu::CharacterTiers::COMMON, Huayu::CharacterTiers::RARE)
  end

  def character_tier=(value)
    level = value.to_i.clamp(Huayu::CharacterTiers::COMMON, Huayu::CharacterTiers::RARE)
    write_prefs("character_tier" => level, "visibility_scale" => "chars")
  end

  VISIBILITY_SCALES = %w[chars tbcl tocfl].freeze
  DEFAULT_TOLERANCE = "at0"

  preference :visibility_scale, one_of: VISIBILITY_SCALES
  preference :visibility_tolerance, one_of: -> { tolerance_steps }, default: DEFAULT_TOLERANCE
  preference :stored_visibility_level, key: "visibility_level", within: -> { 1..Huayu::LevelThresholds::MAX_LEVEL }

  def tolerance_steps = Huayu::LevelLadder::STEPS

  def visibility_level
    visibility_scale == "chars" ? character_tier : stored_visibility_level
  end

  def visibility_level=(value)
    self.stored_visibility_level = value
  end

  def full_visibility? = visibility_scale == "chars" || visibility_level >= Huayu::LevelThresholds::MAX_LEVEL

  def project!(scale:, level:, tolerance: DEFAULT_TOLERANCE)
    self.visibility_scale = scale
    return self.character_tier = level if visibility_scale == "chars"

    self.visibility_level = level
    self.visibility_tolerance = tolerance
  end

  PROJECTION_OPEN = "open"

  def projection
    if visibility_scale != "chars" && stored_visibility_level >= Huayu::LevelThresholds::MAX_LEVEL
      return PROJECTION_OPEN
    end

    "#{visibility_scale}:#{visibility_level}"
  end

  def projection=(value)
    text = value.to_s
    if text == PROJECTION_OPEN
      return project!(scale: "tocfl", level: Huayu::LevelThresholds::MAX_LEVEL, tolerance: visibility_tolerance)
    end

    scale, level = text.split(":")
    project!(scale: scale, level: level.to_i, tolerance: visibility_tolerance)
  end

  def self.projection_options
    tiers = (Huayu::CharacterTiers::COMMON..Huayu::CharacterTiers::RARE).map { |tier| "chars:#{tier}" }
    graded = Huayu::LevelThresholds::SCALES.flat_map do |scale|
      (1...Huayu::LevelThresholds::MAX_LEVEL).map { |level| "#{scale}:#{level}" }
    end

    [PROJECTION_OPEN, *tiers, *graded]
  end

  MAX_MISSES = 99

  def intro_seen_version
    prefs["intro_version"].to_i
  end

  def intro_done?
    prefs["intro_stage"].to_s == "done"
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
end
