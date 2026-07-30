# frozen_string_literal: true

class TextbookLesson < ApplicationRecord
  AUDIO_DIR = "audio/textbook"
  AUDIO_NAME = /\A[A-Z0-9-]+\.mp3\z/

  def self.audio_path(name)
    return nil unless AUDIO_NAME.match?(name.to_s)

    path = AppData.media_path(File.join(AUDIO_DIR, name))
    path.file? ? path : nil
  end

  validates :book, :lesson, :title_en, presence: true
  validates :lesson, uniqueness: {scope: :book}

  scope :ordered, -> { order(:book, :lesson) }
  scope :for_book, -> (book) { where(book:) }

  def self.books
    ordered.group_by(&:book)
  end

  def label
    "B#{book}L#{format("%02d", lesson)}"
  end

  def title_for(locale = I18n.locale)
    return title_ru.presence || title_en if locale.to_s == "ru"

    title_en
  end

  def summary_for(locale = I18n.locale)
    return summary_html_ru.presence || summary_html if locale.to_s == "ru"

    summary_html
  end

  def meaning_for(entry, locale = I18n.locale)
    return entry["meaning_ru"].presence || entry["meaning"] if locale.to_s == "ru"

    entry["meaning"]
  end

  def audio_url(entry)
    name = entry["audio"].to_s
    return unless AUDIO_NAME.match?(name)

    Rails.application.routes.url_helpers.textbook_audio_path(name)
  end

  def words
    vocabulary.reject { |entry| entry["category"] == "Ph" }
  end

  def phrases
    vocabulary.select { |entry| entry["category"] == "Ph" }
  end
end
