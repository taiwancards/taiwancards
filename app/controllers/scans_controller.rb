# frozen_string_literal: true

class ScansController < ApplicationController
  MAX_BODY = (Scans::Upload::MAX_BYTES * Scans::Submission::MAX_PARTS) + 64.kilobytes
  REFUSAL_STATUS = {
    "quota" => :too_many_requests,
    "client" => :too_many_requests,
    "busy" => :service_unavailable,
    "paused" => :service_unavailable,
    "unavailable" => :service_unavailable
  }.freeze

  prepend_before_action :refuse_foreign_upload, only: :create

  def new
    Scan.purge_expired
    @panel = Scans::Panel.new(current_user)
  end

  def create
    upload = Scans::Submission.new(Scans::Submission.files_from(params))
    return refuse(upload.error, :unprocessable_content) unless upload.valid?

    result = Scans::Admission.new(user: current_user, address: request.remote_ip, upload:).call
    return refuse(result.refusal, REFUSAL_STATUS.fetch(result.refusal)) unless result.admitted?

    start_reading(result.scan, upload)
    render(json: {poll: scan_path(result.scan, locale: nil), **Scans::Panel.remaining(current_user)}, status: :accepted)
  end

  def show
    scan = current_user.scans.find_by(id: numeric_id(params[:id]))
    return head(:not_found) if scan.nil?

    scan.fail!("interrupted") if scan.overdue?
    render(json: Scans::Reply.new(scan).as_json)
  end

  private

  def require_authentication
    return super if action_name == "new"

    head(:unauthorized) unless authenticated?
  end

  def refuse_foreign_upload
    length = request.content_length.to_i
    return head(:content_too_large) if length.zero? || length > MAX_BODY
    return head(:forbidden) unless request.origin.present? && request.origin == request.base_url

    head(:forbidden) unless request.headers["Sec-Fetch-Site"].in?([nil, "same-origin"])
  end

  def start_reading(scan, upload)
    ScanJob.perform_later(scan.id, upload.images)
  rescue Concurrent::RejectedExecutionError
    scan.fail!("busy")
  end

  def refuse(reason, status)
    render(json: {error: reason, message: t("scan.refusals.#{reason}")}, status:)
  end
end
