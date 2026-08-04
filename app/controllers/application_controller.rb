# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Returning
  include Authentication
  include Authorization
  include Introduced
  include Voiced
  include PubliclyCacheable

  allow_browser versions: :modern

  stale_when_importmap_changes

  prepend_around_action :switch_locale
  before_action :redirect_to_localised_url
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

    current_user&.seen!
    ActivityEvent.record(
      user: current_user,
      controller: controller_path,
      action: action_name,
      verb: request.request_method,
      path: Locales.strip(request.path)
    )
  end

  def switch_locale(&action)
    I18n.with_locale(Locales.resolve(url: params[:locale], stored: stored_locale, header: browser_locale), &action)
  end

  def redirect_to(target, **)
    super(localised_target(target), **)
  end

  def localised_target(target)
    return target unless target.is_a?(String)

    path = target.delete_prefix(request.base_url)
    return target unless Locales.prefixable?(path)

    Locales.swap(target, I18n.locale)
  end

  def stored_locale = current_user&.locale.presence || cookies[:locale].presence

  def browser_locale = request.headers["Accept-Language"]

  def default_url_options = {locale: I18n.locale}

  def redirect_to_localised_url
    return if params[:locale].present?
    return unless Locales.addressable?(request)

    target = url_for(params.to_unsafe_h.merge(locale: I18n.locale, only_path: true))
    return unless target.start_with?("/#{I18n.locale}")

    redirect_to(target, status: :moved_permanently)
  end
end
