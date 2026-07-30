# frozen_string_literal: true

module Authorization
  extend ActiveSupport::Concern

  private

  def require_restricted_access
    return if current_user&.restricted_access?

    redirect_to(root_path, alert: t("access.restricted_denied"))
  end

  def require_admin
    return if current_user&.admin?

    redirect_to(root_path, alert: t("access.admin_denied"))
  end
end
