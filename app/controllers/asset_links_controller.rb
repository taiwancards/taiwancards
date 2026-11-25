# frozen_string_literal: true

class AssetLinksController < ActionController::Base
  TTL = 1.hour

  def show
    request.session_options[:skip] = true
    return head(:not_found) unless AndroidApp.configured?

    expires_in(TTL, public: true)
    render(json: AndroidApp.asset_links)
  end
end
