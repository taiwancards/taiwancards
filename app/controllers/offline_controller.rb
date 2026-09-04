# frozen_string_literal: true

class OfflineController < ApplicationController
  allow_unauthenticated_access
  publicly_cacheable only: %i[show browse]
  skip_after_action :verify_same_origin_request, only: :worker

  WORKER = Rails.root.join("app/javascript/service_worker.js")

  def show
  end

  def browse
  end

  def worker
    expires_in(0, public: true, must_revalidate: true)
    render(plain: WORKER.read, content_type: "text/javascript")
  end
end
