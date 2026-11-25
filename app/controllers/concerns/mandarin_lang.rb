# frozen_string_literal: true

module MandarinLang
  extend ActiveSupport::Concern

  MARKED_TYPES = %w[text/html text/vnd.turbo-stream.html].freeze
  PLAIN_TYPES = %w[application/json text/plain].freeze

  included do
    after_action :mark_mandarin
  end

  private

  def mark_mandarin
    return unless Locales.writes_han?

    body = response.body
    return if body.blank?

    if MARKED_TYPES.include?(response.media_type)
      response.body = MandarinMarkup.call(body)
    elsif PLAIN_TYPES.include?(response.media_type) && body.include?(HanScript::CLOSE)
      response.body = HanScript.plain(body)
    end
  end
end
