# frozen_string_literal: true

class NewsletterClicksController < ApplicationController
  allow_unauthenticated_access

  def show
    id, url = Newsletters::Tracking.read(params[:token])
    delivery = NewsletterDelivery.find_by(id:) if id
    return redirect_to(root_path) if delivery.nil? || !Newsletters::Tracking.ours?(url.to_s, request.host)

    delivery.record_click!
    redirect_to(url, allow_other_host: false)
  end

  private

  def any_browser? = true
end
