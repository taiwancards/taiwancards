# frozen_string_literal: true

class WebManifestsController < ActionController::Base
  TTL = 1.hour
  STALE = 1.day

  def show
    request.session_options[:skip] = true
    expires_in(TTL, public: true, "stale-while-revalidate": STALE.to_i)
    render(
      json: WebManifest.new(WebManifest.locale_for(params[:locale])).to_h,
      content_type: "application/manifest+json"
    )
  end
end
