# frozen_string_literal: true

class NewsletterUnsubscribesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :create

  before_action :set_delivery

  def show
    render(status: @delivery ? :ok : :not_found)
  end

  def create
    return render(:show, status: :not_found) if @delivery.nil?

    now = Time.current
    @delivery.user.unsubscribe!(at: now)
    @delivery.update_columns(unsubscribed_at: @delivery.unsubscribed_at || now)
    render(:done)
  end

  private

  def any_browser? = true

  def set_delivery
    @delivery = NewsletterDelivery.includes(:user).find_signed(params[:token], purpose: :unsubscribe)
  end
end
