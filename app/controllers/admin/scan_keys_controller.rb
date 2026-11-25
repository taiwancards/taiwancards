# frozen_string_literal: true

module Admin
  class ScanKeysController < ApplicationController
    include ScanKeyGuard

    SAVE_NOTICES = {
      ok: :notice,
      rejected: :alert,
      no_model: :alert,
      unreachable: :alert,
      malformed: :alert,
      no_encryption: :alert
    }.freeze

    def create
      saved = Scans::Credentials.save(params[:secret], expires_on:)
      flash_for(SAVE_NOTICES.fetch(saved.outcome), "scan.admin.key.saved.#{saved.outcome}", hint: saved.hint)
      back
    end

    def check
      outcome = Scans::Credentials.check
      flash_for(outcome == :ok ? :notice : :alert, "scan.admin.key.checked.#{outcome}")
      back
    end

    def destroy
      outcome = Scans::Credentials.forget
      flash_for(outcome == :ok ? :notice : :alert, "scan.admin.key.forgotten.#{outcome}")
      back
    end

    private

    def expires_on
      Date.iso8601(params[:expires_on].to_s)
    rescue Date::Error
      nil
    end

    def flash_for(kind, key, **values) = flash[kind] = t(key, **values)

    def back = redirect_to(admin_scans_path, status: :see_other)
  end
end
