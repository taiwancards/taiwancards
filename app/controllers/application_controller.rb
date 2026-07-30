# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include Introduced

  allow_browser versions: :modern

  stale_when_importmap_changes

  around_action :switch_locale
  after_action :track_activity

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  helper_method :lexeme_page_path

  def lexeme_page_path(lexeme)
    case lexeme.kind.to_s
    when "character"
      character_path(lexeme.text)
    when "radical"
      radical_path(lexeme.text)
    when "sentence"
      sentence_path(lexeme)
    when "measure_word"
      liangci_entry_path(lexeme.text)
    else
      dict_entry_path(lexeme.text)
    end
  end

  private

  def numeric_id(value)
    value.to_s.match?(/\A\d+\z/) ? value : nil
  end

  def render_not_found
    respond_to do |format|
      format.html { render("shared/not_found", status: :not_found, layout: true) }
      format.any { head(:not_found) }
    end
  end

  def track_activity
    return if impersonating?
    return unless response.successful? || response.redirect?
    return unless request.format.html?

    ActivityEvent.record(
      user: current_user,
      controller: controller_path,
      action: action_name,
      verb: request.request_method,
      path: request.path
    )
  end

  def switch_locale(&action)
    locale = cookies[:locale].presence || current_user&.locale.presence || I18n.default_locale
    locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
    I18n.with_locale(locale, &action)
  end
end
