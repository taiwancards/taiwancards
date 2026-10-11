# frozen_string_literal: true

class RemindersController < ApplicationController
  allow_unauthenticated_access except: :enable
  skip_forgery_protection only: :run

  def run
    expected = ENV["REMINDERS_TOKEN"].to_s
    given = request.authorization.to_s.delete_prefix("Bearer ")
    return head(:unauthorized) if expected.empty? || !ActiveSupport::SecurityUtils.secure_compare(given, expected)

    render(json: {queued: Reminders::Dispatch.new.call.size})
  end

  def enable
    current_user.mailing_source = "prompt"
    current_user.update!(reminders: true)
    redirect_to(referring_path || desk_path, notice: t("reminders.session.enabled"))
  end
end
