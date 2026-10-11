# frozen_string_literal: true

module ReadOnlyImpersonation
  extend ActiveSupport::Concern

  BROWSER_ONLY = %w[
    admin/impersonations#destroy
    sessions#destroy
    locales#update
    detail_prefs#update
  ].to_set.freeze
  ACTING = %w[omniauth_callbacks#google_oauth2].to_set.freeze

  included do
    prepend_around_action :keep_impersonation_read_only
  end

  private

  def keep_impersonation_read_only
    return yield unless impersonating?

    trace_impersonation("before")
    return refuse_impersonated_change unless harmless_request?

    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end

  ensure
    trace_impersonation("after") if impersonating?
  end

  def trace_impersonation(stage)
    Rails.logger.info(
      "impersonation #{stage}: true_user=#{true_user&.id} session=#{session[:impersonated_user_id].inspect} " \
        "impersonated=#{impersonated_user&.id} current=#{Current.user&.id} resolved=#{Current.user_resolved?.inspect}"
    )
  end

  def harmless_request?
    action = "#{controller_path}##{action_name}"
    return false if ACTING.include?(action)

    request.get? || request.head? || BROWSER_ONLY.include?(action)
  end

  def refuse_impersonated_change
    message = t("admin.impersonation_read_only")
    if request.format.html? || request.format.turbo_stream?
      redirect_back(fallback_location: root_path, alert: message, status: :see_other)
    else
      render(json: {error: message}, status: :forbidden)
    end
  end
end
