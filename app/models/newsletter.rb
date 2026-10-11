# frozen_string_literal: true

class Newsletter < ApplicationRecord
  LOCALES = %w[en ru].freeze
  MAX_BUTTONS = 3
  SAFE_URL = %r{\A(?:https?://|/(?!/)|mailto:)}i
  AUDIENCES = %w[all filtered picked].freeze

  has_many :images, class_name: "NewsletterImage", dependent: :delete_all
  has_many :deliveries, class_name: "NewsletterDelivery", dependent: :delete_all

  scope :recent, -> { order(created_at: :desc) }

  before_save :clean_bodies

  def self.recipients
    subscribed = User.where.not(google_uid: nil).where(newsletter_unsubscribed_at: nil)
    owner = User.owner_google_email
    owner ? subscribed.or(User.where(google_email: owner)) : subscribed
  end

  def audience_mode = audience["mode"].presence_in(AUDIENCES) || "all"

  def audience_levels = Array(audience["levels"])

  def audience_goals = Array(audience["goals"])

  def audience_user_ids = Array(audience["user_ids"]).map(&:to_i)

  def audience_recipients
    scope = self.class.recipients
    case audience_mode
    when "picked"
      scope.where(id: audience_user_ids)
    when "filtered"
      scope = scope.where("COALESCE(users.prefs->>'level', 'zero') IN (?)", audience_levels) if audience_levels.any?
      scope = scope.where("users.prefs->>'goal' IN (?)", audience_goals) if audience_goals.any?
      scope
    else
      scope
    end
  end

  def subject(locale) = self["subject_#{locale}"].to_s

  def preheader(locale) = self["preheader_#{locale}"].to_s

  def body(locale) = self["body_#{locale}"].to_s

  def buttons_for(locale)
    Array(buttons).filter_map { |button|
      label = button["label_#{locale}"].to_s.strip
      url = button["url"].to_s.strip
      {label:, url:} if label.present? && url.match?(SAFE_URL)
    }
  end

  def complete? = LOCALES.all? { |locale|
    subject(locale).present? && Newsletters::PlainText.call(body(locale)).present?
  }

  def sent? = sent_at.present?

  def title = subject("ru").presence || subject("en").presence || "##{id}"

  private

  def clean_bodies
    LOCALES.each { |locale| self["body_#{locale}"] = Newsletters::Body.clean(body(locale)) }
    self.buttons = Array(buttons).first(MAX_BUTTONS).map { |button| button.to_h.slice("label_en", "label_ru", "url") }
    self.audience = {
      "mode" => audience_mode,
      "levels" => audience_levels & User::LEVELS,
      "goals" => audience_goals & User::GOALS,
      "user_ids" => audience_user_ids.select(&:positive?).uniq
    }
  end
end
