# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user, :true_user, :impersonating?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action(:require_authentication, **options)
    end
  end

  private

  def authenticated?
    current_user.present?
  end

  def true_user
    return @true_user if defined?(@true_user)

    id = cookies.signed[:user_id]
    @true_user = id.present? ? User.find_by(id: id) : nil
    forget_deleted_account if id.present? && @true_user.nil?
    @true_user ||= User.default_owner
  end

  def forget_deleted_account
    terminate_session
    PubliclyCacheable::PERSONAL.each { |name| cookies.delete(name) }
    cookies.delete(:locale)
  end

  def impersonated_user
    return nil unless true_user&.admin?
    return nil if session[:impersonated_user_id].blank?

    return @impersonated_user if defined?(@impersonated_user)

    @impersonated_user = User.find_by(id: session[:impersonated_user_id])
  end

  def impersonating?
    impersonated_user.present?
  end

  def current_user
    return Current.user if Current.user_resolved?

    Current.user = impersonated_user || true_user
  end

  def require_authentication
    return if authenticated?

    remember_return_path(request.fullpath) if request.get? && request.format.html?
    redirect_to(login_path)
  end

  def start_new_session_for(user)
    Current.user = user
    cookies.signed.permanent[:user_id] = {value: user.id, httponly: true, same_site: :lax}
  end

  def terminate_session
    Current.user = nil
    session.delete(:impersonated_user_id)
    cookies.delete(:user_id)
  end
end
