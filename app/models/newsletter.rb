# frozen_string_literal: true

class Newsletter < ApplicationRecord
  LOCALES = %w[en ru].freeze
  MAX_BUTTONS = 3
  SAFE_URL = %r{\A(?:https?://|/(?!/)|mailto:)}i

  has_many :images, class_name: "NewsletterImage", dependent: :delete_all
  has_many :deliveries, class_name: "NewsletterDelivery", dependent: :delete_all

  scope :recent, -> { order(created_at: :desc) }

  before_save :clean_bodies

  def self.recipients
    subscribed = User.where.not(google_uid: nil).where(newsletter_unsubscribed_at: nil)
    owner = User.owner_google_email
    owner ? subscribed.or(User.where(google_email: owner)) : subscribed
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
  end
end
